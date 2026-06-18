import Foundation

struct MonthSummary {
    let referenceDate: Date
    private let transactions: [Transaction]
    private let pendingReceivables: [Receivable]
    private let calendar: Calendar
    private let now: Date

    init(
        referenceDate: Date,
        transactions: [Transaction],
        pendingReceivables: [Receivable] = [],
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        self.referenceDate = referenceDate
        self.transactions = transactions
        self.pendingReceivables = pendingReceivables
        self.calendar = calendar
        self.now = now
    }

    // MARK: - Month bounds

    var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 0)
    }

    var monthlyTransactions: [Transaction] {
        let interval = monthInterval
        return transactions.filter { interval.contains(reportingDate(for: $0)) }
    }

    /// Realized & spendable: excludes internal transfers (e.g. bank ↔ investment legs)
    /// so they don't inflate `totalIncome` / `totalExpense` / pace.
    var realizedMonthlyTransactions: [Transaction] {
        monthlyTransactions.filter { $0.occurredOn <= now && !$0.isTransfer }
    }

    var plannedMonthlyTransactions: [Transaction] {
        monthlyTransactions.filter { $0.occurredOn > now && !$0.isTransfer }
    }

    /// Net amount moved INTO investment accounts during the month (aportes − resgates).
    var investedThisMonth: Decimal {
        let invested = monthlyTransactions.filter {
            $0.isTransfer && $0.occurredOn <= now && $0.account?.kind == .investment
        }
        return invested.reduce(Decimal(0)) { partial, txn in
            switch txn.kind {
            case .income:  return partial + txn.amount   // aporte recebido pela conta investimento
            case .expense: return partial - txn.amount   // resgate (saída da invest)
            }
        }
    }

    private func reportingDate(for transaction: Transaction) -> Date {
        switch transaction.kind {
        case .expense:
            return transaction.reportingDate(calendar: calendar)
        case .income:
            return transaction.occurredOn
        }
    }

    // MARK: - Totals (realized only — what already hit the books)

    var totalIncome: Decimal {
        realizedMonthlyTransactions
            .filter { $0.kind == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var totalExpense: Decimal {
        realizedMonthlyTransactions
            .filter { $0.kind == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var plannedIncome: Decimal {
        plannedMonthlyTransactions
            .filter { $0.kind == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var plannedExpense: Decimal {
        plannedMonthlyTransactions
            .filter { $0.kind == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Sum of pending Receivables expected to land in the current month.
    var pendingReceivableIncome: Decimal {
        let interval = monthInterval
        return pendingReceivables
            .filter { $0.isPending && interval.contains($0.expectedDate) }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var hasPlanned: Bool {
        plannedIncome > 0 || plannedExpense > 0 || pendingReceivableIncome > 0
    }

    /// Total income realistically expected for the whole month:
    /// already-realized + planned (future-dated) income transactions + pending receivables.
    var expectedIncome: Decimal {
        totalIncome + plannedIncome + pendingReceivableIncome
    }

    /// Honest cash-flow saldo: what actually came in minus what actually went out so far.
    /// Does NOT inflate with expected/budgeted income — that's `expectedIncome` minus expense.
    var balance: Decimal {
        totalIncome - totalExpense
    }

    /// Forward-looking saldo: what the month is projected to end at if expected income
    /// materializes and planned expenses go through.
    var projectedBalance: Decimal {
        expectedIncome - totalExpense - plannedExpense
    }

    var spentRatio: Double {
        let base = expectedIncome
        guard base > 0 else { return 0 }
        let ratio = NSDecimalNumber(decimal: totalExpense / base).doubleValue
        return min(max(ratio, 0), 1.5)
    }

    // MARK: - Pace

    var dayProgress: Double {
        let interval = monthInterval
        guard interval.duration > 0 else { return 0 }
        let elapsed = referenceDate.timeIntervalSince(interval.start)
        return min(max(elapsed / interval.duration, 0), 1)
    }

    var daysRemaining: Int {
        let interval = monthInterval
        let end = interval.end
        let remaining = calendar.dateComponents([.day], from: referenceDate, to: end).day ?? 0
        return max(remaining, 0)
    }

    var dailyBudgetRemaining: Decimal {
        guard daysRemaining > 0 else { return 0 }
        let remaining = max(expectedIncome - totalExpense, 0)
        return remaining / Decimal(daysRemaining)
    }

    /// Returns a value in [0, 1.5+] — 1 means perfectly on track.
    /// >1 means overspending vs calendar pace; <1 means under pace.
    var paceFactor: Double {
        guard dayProgress > 0.01 else { return 0 }
        return spentRatio / dayProgress
    }

    var paceState: PaceState {
        switch paceFactor {
        case ..<0.9: return .underspending
        case 0.9...1.05: return .onTrack
        case 1.05...1.2: return .warning
        default: return .danger
        }
    }

    // MARK: - Breakdowns

    struct CategoryAggregate: Identifiable {
        let id: UUID
        let category: Category
        let total: Decimal
        let count: Int
    }

    struct AccountAggregate: Identifiable {
        let id: UUID
        let account: Account
        let total: Decimal
        let count: Int
    }

    var expensesByCategory: [CategoryAggregate] {
        let expenses = realizedMonthlyTransactions.filter { $0.kind == .expense && $0.category != nil }
        let grouped = Dictionary(grouping: expenses) { $0.category!.id }
        return grouped.compactMap { id, items -> CategoryAggregate? in
            guard let category = items.first?.category else { return nil }
            return CategoryAggregate(
                id: id,
                category: category,
                total: items.reduce(Decimal(0)) { $0 + $1.amount },
                count: items.count
            )
        }
        .sorted { $0.total > $1.total }
    }

    var expensesByAccount: [AccountAggregate] {
        let expenses = realizedMonthlyTransactions.filter { $0.kind == .expense && $0.account != nil }
        let grouped = Dictionary(grouping: expenses) { $0.account!.id }
        return grouped.compactMap { id, items -> AccountAggregate? in
            guard let account = items.first?.account else { return nil }
            return AccountAggregate(
                id: id,
                account: account,
                total: items.reduce(Decimal(0)) { $0 + $1.amount },
                count: items.count
            )
        }
        .sorted { $0.total > $1.total }
    }
}

enum PaceState {
    case underspending
    case onTrack
    case warning
    case danger

    var label: String {
        switch self {
        case .underspending: return "Gastando abaixo do ritmo"
        case .onTrack: return "No ritmo certo"
        case .warning: return "Acima do ritmo"
        case .danger: return "Gastando muito rápido"
        }
    }

    var symbol: String {
        switch self {
        case .underspending: return "tortoise.fill"
        case .onTrack: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "flame.fill"
        }
    }
}
