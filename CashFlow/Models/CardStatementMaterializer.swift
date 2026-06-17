import Foundation
import SwiftData

/// Idempotently turns closed credit-card statements into pending `Bill`s.
/// One Bill per (card, closingDate) pair. Safe to call on app launch.
@MainActor
enum CardStatementMaterializer {

    static func materializeAll(
        context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) {
        let accountDescriptor = FetchDescriptor<Account>(
            predicate: #Predicate<Account> { !$0.isArchived }
        )
        guard let accounts = try? context.fetch(accountDescriptor) else { return }
        let cards = accounts.filter { $0.hasBillingCycle }
        guard !cards.isEmpty else { return }

        let allTransactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let existingBills = (try? context.fetch(FetchDescriptor<Bill>())) ?? []

        for card in cards {
            materialize(
                card: card,
                allTransactions: allTransactions,
                existingBills: existingBills,
                now: now,
                calendar: calendar,
                context: context
            )
        }
    }

    static func materialize(
        card: Account,
        allTransactions: [Transaction],
        existingBills: [Bill],
        now: Date,
        calendar: Calendar,
        context: ModelContext
    ) {
        let cardTxns = allTransactions.filter { $0.account?.id == card.id }
        guard !cardTxns.isEmpty else { return }

        // Group transactions by their closing date.
        var byClosing: [Date: [Transaction]] = [:]
        for txn in cardTxns {
            guard let closing = card.closingDate(for: txn.occurredOn, calendar: calendar) else { continue }
            byClosing[closing, default: []].append(txn)
        }

        for (closingDate, txns) in byClosing where closingDate <= now {
            // Net amount in this cycle: expenses − payments. Negative means credit; skip.
            let net = txns.reduce(Decimal(0)) { partial, txn in
                switch txn.kind {
                case .expense: return partial + txn.amount
                case .income:  return partial - txn.amount
                }
            }
            guard net > 0 else { continue }

            // Skip if a Bill already exists for this (card, closingDate).
            let alreadyExists = existingBills.contains { bill in
                bill.cardStatementSource?.id == card.id &&
                (bill.cardStatementClosingDate.map { calendar.isDate($0, inSameDayAs: closingDate) } ?? false)
            }
            if alreadyExists { continue }

            guard let dueDate = card.paymentDueDate(for: closingDate, calendar: calendar) else { continue }

            let bill = Bill(
                name: "Fatura \(card.name) · \(monthLabel(for: closingDate))",
                amount: net,
                dueDate: dueDate,
                status: .pending,
                cardStatementSource: card,
                cardStatementClosingDate: closingDate
            )
            context.insert(bill)
            BillNotifications.schedule(for: bill)
        }
    }

    private static func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM/yy"
        formatter.locale = Money.locale
        return formatter.string(from: date).capitalized
    }
}
