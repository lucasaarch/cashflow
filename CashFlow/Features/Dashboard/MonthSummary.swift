import Foundation

struct MonthSummary {
    let referenceDate: Date
    let monthlyIncomeBudget: Decimal
    private let transactions: [Transaction]
    private let calendar: Calendar

    init(referenceDate: Date, monthlyIncomeBudget: Decimal, transactions: [Transaction], calendar: Calendar = .current) {
        self.referenceDate = referenceDate
        self.monthlyIncomeBudget = monthlyIncomeBudget
        self.transactions = transactions
        self.calendar = calendar
    }

    // MARK: - Month bounds

    var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: referenceDate) ?? DateInterval(start: referenceDate, duration: 0)
    }

    var monthlyTransactions: [Transaction] {
        let interval = monthInterval
        return transactions.filter { interval.contains($0.occurredOn) }
    }

    // MARK: - Totals

    var totalIncome: Decimal {
        monthlyTransactions
            .filter { $0.kind == .income }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var totalExpense: Decimal {
        monthlyTransactions
            .filter { $0.kind == .expense }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    var balance: Decimal {
        max(monthlyIncomeBudget, totalIncome) - totalExpense
    }

    var spentRatio: Double {
        let base = max(monthlyIncomeBudget, totalIncome)
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
        let remaining = max(balance, 0)
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
        let expenses = monthlyTransactions.filter { $0.kind == .expense && $0.category != nil }
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
        let expenses = monthlyTransactions.filter { $0.kind == .expense && $0.account != nil }
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
