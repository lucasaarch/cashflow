import Foundation

struct SpendingHistoryContext {
    struct MonthExpense: Identifiable {
        let month: Date
        let expense: Decimal
        var id: Date { month }
    }

    enum Trend: Equatable, Sendable {
        case belowUsual
        case onUsual
        case aboveUsual
        case insufficientData

        var label: String {
            switch self {
            case .belowUsual: return "Gastando menos que o habitual"
            case .onUsual: return "No seu ritmo usual"
            case .aboveUsual: return "Gastando mais que o habitual"
            case .insufficientData: return "Histórico insuficiente"
            }
        }

        var symbol: String {
            switch self {
            case .belowUsual: return "tortoise.fill"
            case .onUsual: return "checkmark.circle.fill"
            case .aboveUsual: return "exclamationmark.triangle.fill"
            case .insufficientData: return "clock.arrow.circlepath"
            }
        }
    }

    let referenceDate: Date
    let currentExpense: Decimal
    let dayProgress: Double
    let historicalMonths: [MonthExpense]

    var sampleCount: Int { historicalMonths.count }

    var averageMonthlyExpense: Decimal? {
        guard !historicalMonths.isEmpty else { return nil }
        let total = historicalMonths.reduce(Decimal(0)) { $0 + $1.expense }
        return total / Decimal(historicalMonths.count)
    }

    var typicalExpenseAtCurrentProgress: Decimal? {
        guard let average = averageMonthlyExpense, dayProgress > 0.01 else { return nil }
        return average * Decimal(dayProgress)
    }

    var projectedMonthExpense: Decimal? {
        guard dayProgress > 0.01 else { return nil }
        return currentExpense / Decimal(dayProgress)
    }

    var progressVsTypicalRatio: Double? {
        guard let typical = typicalExpenseAtCurrentProgress, typical > 0 else { return nil }
        return NSDecimalNumber(decimal: currentExpense / typical).doubleValue
    }

    var projectedVsAverageRatio: Double? {
        guard let average = averageMonthlyExpense, average > 0,
              let projected = projectedMonthExpense else { return nil }
        return NSDecimalNumber(decimal: projected / average).doubleValue
    }

    var progressTrend: Trend {
        guard sampleCount >= 2, let ratio = progressVsTypicalRatio else { return .insufficientData }
        switch ratio {
        case ..<0.9: return .belowUsual
        case 0.9...1.1: return .onUsual
        default: return .aboveUsual
        }
    }

    static func analyze(
        referenceDate: Date,
        transactions: [Transaction],
        lookbackMonths: Int = 6,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> SpendingHistoryContext {
        let currentSummary = MonthSummary(
            referenceDate: referenceDate,
            transactions: transactions,
            calendar: calendar,
            now: now
        )

        var historical: [MonthExpense] = []
        for offset in 1...lookbackMonths {
            guard let month = calendar.date(byAdding: .month, value: -offset, to: referenceDate) else { continue }
            let asOf = endOfMonth(for: month, calendar: calendar, now: now)
            let summary = MonthSummary(
                referenceDate: month,
                transactions: transactions,
                calendar: calendar,
                now: asOf
            )
            historical.append(MonthExpense(month: month, expense: summary.totalExpense))
        }

        return SpendingHistoryContext(
            referenceDate: referenceDate,
            currentExpense: currentSummary.totalExpense,
            dayProgress: currentSummary.dayProgress,
            historicalMonths: historical.reversed()
        )
    }

    private static func endOfMonth(for month: Date, calendar: Calendar, now: Date) -> Date {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return month }
        return min(interval.end.addingTimeInterval(-1), now)
    }
}
