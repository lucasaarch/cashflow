import Foundation

enum ReportPeriod: String, CaseIterable, Identifiable {
    case threeMonths = "3m"
    case sixMonths = "6m"
    case twelveMonths = "12m"
    case yearToDate = "ytd"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .threeMonths: return "3 meses"
        case .sixMonths: return "6 meses"
        case .twelveMonths: return "12 meses"
        case .yearToDate: return "Ano atual"
        }
    }

    func monthCount(referenceDate: Date, calendar: Calendar) -> Int {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .twelveMonths: return 12
        case .yearToDate:
            let month = calendar.component(.month, from: referenceDate)
            return max(month, 1)
        }
    }
}

struct ReportBuilder {
    let referenceDate: Date
    let period: ReportPeriod
    private let transactions: [Transaction]
    private let accounts: [Account]
    private let bills: [Bill]
    private let calendar: Calendar
    private let now: Date

    init(
        referenceDate: Date = .now,
        period: ReportPeriod = .sixMonths,
        transactions: [Transaction],
        accounts: [Account],
        bills: [Bill] = [],
        calendar: Calendar = .current,
        now: Date = .now
    ) {
        self.referenceDate = referenceDate
        self.period = period
        self.transactions = transactions
        self.accounts = accounts.filter { !$0.isArchived }
        self.bills = bills
        self.calendar = calendar
        self.now = now
    }

    // MARK: - Period bounds

    var monthAnchors: [Date] {
        let count = period.monthCount(referenceDate: referenceDate, calendar: calendar)
        guard let endMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate)) else {
            return []
        }
        return (0..<count).compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: endMonth)
        }.reversed()
    }

    var periodInterval: DateInterval? {
        guard let first = monthAnchors.first,
              let lastInterval = calendar.dateInterval(of: .month, for: monthAnchors.last ?? referenceDate) else {
            return nil
        }
        return DateInterval(start: first, end: lastInterval.end)
    }

    // MARK: - Cash flow

    struct MonthlyCashFlowPoint: Identifiable {
        let month: Date
        let income: Decimal
        let expense: Decimal
        var id: Date { month }
        var net: Decimal { income - expense }
    }

    var cashFlowSeries: [MonthlyCashFlowPoint] {
        monthAnchors.map { month in
            let summary =             MonthSummary(
                referenceDate: month,
                transactions: transactions,
                calendar: calendar,
                now: endOfMonth(for: month)
            )
            return MonthlyCashFlowPoint(
                month: month,
                income: summary.totalIncome,
                expense: summary.totalExpense
            )
        }
    }

    // MARK: - Categories

    struct CategoryExpensePoint: Identifiable {
        let id: UUID
        let category: Category
        let total: Decimal
    }

    var topCategoryExpenses: [CategoryExpensePoint] {
        guard let interval = periodInterval else { return [] }
        let expenses = transactions.filter {
            !$0.isTransfer &&
            $0.kind == .expense &&
            $0.category != nil &&
            interval.contains(reportingDate(for: $0))
        }
        let grouped = Dictionary(grouping: expenses) { $0.category!.id }
        return grouped.compactMap { id, items -> CategoryExpensePoint? in
            guard let category = items.first?.category else { return nil }
            return CategoryExpensePoint(
                id: id,
                category: category,
                total: items.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.total > $1.total }
        .prefix(8)
        .map { $0 }
    }

    // MARK: - Net worth

    struct NetWorthPoint: Identifiable {
        let month: Date
        let liquid: Decimal
        let debt: Decimal
        let invested: Decimal
        var id: Date { month }
        var netWorth: Decimal { liquid - debt + invested }
    }

    var netWorthSeries: [NetWorthPoint] {
        monthAnchors.map { month in
            let asOf = endOfMonth(for: month)
            let overview = FinancialOverview(
                accounts: accounts,
                transactions: transactions,
                asOf: asOf
            )
            return NetWorthPoint(
                month: month,
                liquid: overview.liquidBalance,
                debt: overview.debtBalance,
                invested: overview.totalInvestedBalance
            )
        }
    }

    // MARK: - Investments

    struct InvestmentFlowPoint: Identifiable {
        let month: Date
        let netInvested: Decimal
        var id: Date { month }
    }

    var investmentFlowSeries: [InvestmentFlowPoint] {
        monthAnchors.map { month in
            let summary =             MonthSummary(
                referenceDate: month,
                transactions: transactions,
                calendar: calendar,
                now: endOfMonth(for: month)
            )
            return InvestmentFlowPoint(month: month, netInvested: summary.investedThisMonth)
        }
    }

    // MARK: - Month comparison

    struct MonthComparison {
        let currentIncome: Decimal
        let currentExpense: Decimal
        let previousIncome: Decimal
        let previousExpense: Decimal

        var incomeDeltaPercent: Double? { Self.percentDelta(from: previousIncome, to: currentIncome) }
        var expenseDeltaPercent: Double? { Self.percentDelta(from: previousExpense, to: currentExpense) }

        private static func percentDelta(from previous: Decimal, to current: Decimal) -> Double? {
            guard previous > 0 else { return nil }
            let delta = current - previous
            return NSDecimalNumber(decimal: delta / previous).doubleValue * 100
        }
    }

    var monthComparison: MonthComparison {
        let current = MonthSummary(
            referenceDate: referenceDate,
            transactions: transactions,
            calendar: calendar,
            now: now
        )
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        let previous = MonthSummary(
            referenceDate: previousMonth,
            transactions: transactions,
            calendar: calendar,
            now: endOfMonth(for: previousMonth)
        )
        return MonthComparison(
            currentIncome: current.totalIncome,
            currentExpense: current.totalExpense,
            previousIncome: previous.totalIncome,
            previousExpense: previous.totalExpense
        )
    }

    // MARK: - Bills

    struct BillMonthGroup: Identifiable {
        let month: Date
        let bills: [Bill]
        let total: Decimal
        var id: Date { month }
    }

    var pendingBillsByMonth: [BillMonthGroup] {
        let pending = bills.filter { $0.isPending }
        let grouped = Dictionary(grouping: pending) { bill in
            calendar.date(from: calendar.dateComponents([.year, .month], from: bill.dueDate)) ?? bill.dueDate
        }
        return grouped.map { month, items in
            BillMonthGroup(
                month: month,
                bills: items.sorted { $0.dueDate < $1.dueDate },
                total: items.reduce(0) { $0 + $1.amount }
            )
        }
        .sorted { $0.month < $1.month }
    }

    // MARK: - Helpers

    private func reportingDate(for transaction: Transaction) -> Date {
        switch transaction.kind {
        case .expense: return transaction.reportingDate(calendar: calendar)
        case .income: return transaction.occurredOn
        }
    }

    private func endOfMonth(for month: Date) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return month }
        return min(interval.end.addingTimeInterval(-1), now)
    }
}
