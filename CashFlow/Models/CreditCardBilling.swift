import Foundation

// MARK: - Statement models

struct CreditCardStatement {
    let closingDate: Date?
    let dueDate: Date?
    let items: [CreditCardStatementLine]
    let totalDebt: Decimal
    let hasBillingCycle: Bool

    var total: Decimal { totalDebt }

    var isEmpty: Bool {
        totalDebt == 0 && items.isEmpty
    }
}

enum CreditCardStatementLine: Identifiable {
    case openingBalance(Decimal)
    case expense(Transaction)
    case payment(Transaction)

    var id: String {
        switch self {
        case .openingBalance:
            return "opening-balance"
        case .expense(let transaction), .payment(let transaction):
            return transaction.id.uuidString
        }
    }

    var debtContribution: Decimal {
        switch self {
        case .openingBalance(let amount):
            return amount
        case .expense(let transaction):
            return transaction.amount
        case .payment(let transaction):
            return -transaction.amount
        }
    }
}

// MARK: - Billing-cycle helpers

enum CreditCardBilling {
    /// Day of month (1…31). Values above the month's length clamp to the last day.
    static func date(onDay day: Int, inMonthOf reference: Date, calendar: Calendar = .current) -> Date? {
        guard day >= 1, day <= 31 else { return nil }
        var components = calendar.dateComponents([.year, .month], from: reference)
        components.day = 1
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else { return nil }
        components.day = min(day, range.count)
        return calendar.startOfDay(for: calendar.date(from: components)!)
    }

    static func closingDate(
        for purchaseDate: Date,
        closingDay: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard closingDay >= 1, closingDay <= 31 else { return nil }
        let purchaseDay = calendar.component(.day, from: purchaseDate)
        if purchaseDay <= closingDay {
            return date(onDay: closingDay, inMonthOf: purchaseDate, calendar: calendar)
        }
        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: purchaseDate) else { return nil }
        return date(onDay: closingDay, inMonthOf: nextMonth, calendar: calendar)
    }

    static func dueDate(
        forClosingDate closing: Date,
        closingDay: Int,
        dueDay: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard dueDay >= 1, dueDay <= 31 else { return nil }
        if dueDay > closingDay {
            return date(onDay: dueDay, inMonthOf: closing, calendar: calendar)
        }
        guard let monthAfterClose = calendar.date(byAdding: .month, value: 1, to: closing) else { return nil }
        return date(onDay: dueDay, inMonthOf: monthAfterClose, calendar: calendar)
    }

    static func dueDate(
        for purchaseDate: Date,
        closingDay: Int,
        dueDay: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard dueDay >= 1, dueDay <= 31,
              let closing = closingDate(for: purchaseDate, closingDay: closingDay, calendar: calendar) else {
            return nil
        }
        return dueDate(forClosingDate: closing, closingDay: closingDay, dueDay: dueDay, calendar: calendar)
    }

    /// Returns the billing cycle that is currently open as of `asOf`.
    /// Before the closing day: accumulating for this month's close.
    /// After close but before due: the statement that just closed is awaiting payment.
    /// After due: accumulating for the next month's close.
    static func openCycle(
        asOf: Date,
        closingDay: Int,
        dueDay: Int,
        calendar: Calendar = .current
    ) -> (closing: Date, due: Date)? {
        guard closingDay >= 1, dueDay >= 1 else { return nil }
        let asOfDay = calendar.startOfDay(for: asOf)
        let day = calendar.component(.day, from: asOfDay)

        if day <= closingDay {
            guard let closing = date(onDay: closingDay, inMonthOf: asOf, calendar: calendar),
                  let due = dueDate(forClosingDate: closing, closingDay: closingDay, dueDay: dueDay, calendar: calendar) else {
                return nil
            }
            return (closing, due)
        }

        guard let closingThisMonth = date(onDay: closingDay, inMonthOf: asOf, calendar: calendar),
              let dueThisMonth = dueDate(forClosingDate: closingThisMonth, closingDay: closingDay, dueDay: dueDay, calendar: calendar) else {
            return nil
        }

        if asOfDay <= dueThisMonth {
            return (closingThisMonth, dueThisMonth)
        }

        guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: asOf),
              let closing = date(onDay: closingDay, inMonthOf: nextMonth, calendar: calendar),
              let due = dueDate(forClosingDate: closing, closingDay: closingDay, dueDay: dueDay, calendar: calendar) else {
            return nil
        }
        return (closing, due)
    }

    static func openStatement(
        for account: Account,
        transactions: [Transaction],
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> CreditCardStatement {
        guard account.kind == .creditCard else {
            return CreditCardStatement(
                closingDate: nil,
                dueDate: nil,
                items: [],
                totalDebt: 0,
                hasBillingCycle: false
            )
        }

        let accountTransactions = transactions
            .filter { $0.account?.id == account.id && $0.occurredOn >= account.openingDate }
            .sorted { $0.occurredOn < $1.occurredOn }

        let balance = account.currentBalance(considering: transactions)
        let totalDebt = max(0, -balance)

        guard account.hasBillingCycle,
              let cycle = openCycle(
                asOf: asOf,
                closingDay: account.closingDay,
                dueDay: account.dueDay,
                calendar: calendar
              ) else {
            return simpleStatement(
                accountTransactions: accountTransactions,
                totalDebt: totalDebt
            )
        }

        let cycleTransactions = accountTransactions.filter { transaction in
            guard let closing = account.closingDate(for: transaction.occurredOn, calendar: calendar) else {
                return false
            }
            return calendar.isDate(closing, inSameDayAs: cycle.closing)
        }

        let cycleNet = cycleTransactions.reduce(Decimal(0)) { partial, transaction in
            switch transaction.kind {
            case .expense: return partial + transaction.amount
            case .income: return partial - transaction.amount
            }
        }

        let residual = max(0, totalDebt - cycleNet)
        var items: [CreditCardStatementLine] = []
        if residual > 0 {
            items.append(.openingBalance(residual))
        }
        for transaction in cycleTransactions {
            switch transaction.kind {
            case .expense:
                items.append(.expense(transaction))
            case .income:
                items.append(.payment(transaction))
            }
        }

        return CreditCardStatement(
            closingDate: cycle.closing,
            dueDate: cycle.due,
            items: items,
            totalDebt: totalDebt,
            hasBillingCycle: true
        )
    }

    private static func simpleStatement(
        accountTransactions: [Transaction],
        totalDebt: Decimal
    ) -> CreditCardStatement {
        let cycleNet = accountTransactions.reduce(Decimal(0)) { partial, transaction in
            switch transaction.kind {
            case .expense: return partial + transaction.amount
            case .income: return partial - transaction.amount
            }
        }
        let residual = max(0, totalDebt - cycleNet)
        var items: [CreditCardStatementLine] = []
        if residual > 0 {
            items.append(.openingBalance(residual))
        }
        for transaction in accountTransactions {
            switch transaction.kind {
            case .expense:
                items.append(.expense(transaction))
            case .income:
                items.append(.payment(transaction))
            }
        }
        return CreditCardStatement(
            closingDate: nil,
            dueDate: nil,
            items: items,
            totalDebt: totalDebt,
            hasBillingCycle: false
        )
    }
}

extension Account {
    var hasBillingCycle: Bool {
        kind == .creditCard && closingDay >= 1 && dueDay >= 1
    }

    var billingCycleCaption: String? {
        guard hasBillingCycle else { return nil }
        return "Fecha dia \(closingDay) · Vence dia \(dueDay)"
    }

    func closingDate(for purchaseDate: Date, calendar: Calendar = .current) -> Date? {
        guard kind == .creditCard else { return nil }
        return CreditCardBilling.closingDate(for: purchaseDate, closingDay: closingDay, calendar: calendar)
    }

    func paymentDueDate(for purchaseDate: Date, calendar: Calendar = .current) -> Date? {
        guard kind == .creditCard else { return nil }
        return CreditCardBilling.dueDate(
            for: purchaseDate,
            closingDay: closingDay,
            dueDay: dueDay,
            calendar: calendar
        )
    }

    func openStatement(
        considering transactions: [Transaction],
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> CreditCardStatement {
        CreditCardBilling.openStatement(for: self, transactions: transactions, asOf: asOf, calendar: calendar)
    }
}

extension Transaction {
    /// Date used for monthly expense totals. Card purchases count in the month they are due.
    func reportingDate(calendar: Calendar = .current) -> Date {
        guard kind == .expense,
              let account,
              account.hasBillingCycle,
              let due = account.paymentDueDate(for: occurredOn, calendar: calendar) else {
            return occurredOn
        }
        return due
    }

    func billingCycleCaption(calendar: Calendar = .current) -> String? {
        guard kind == .expense,
              let account,
              account.hasBillingCycle,
              let closing = account.closingDate(for: occurredOn, calendar: calendar),
              let due = account.paymentDueDate(for: occurredOn, calendar: calendar) else {
            return nil
        }
        let closingText = closing.formatted(.dateTime.day().month(.twoDigits).locale(Money.locale))
        let dueText = due.formatted(.dateTime.day().month(.twoDigits).locale(Money.locale))
        return "Fecha \(closingText) · Vence \(dueText)"
    }
}
