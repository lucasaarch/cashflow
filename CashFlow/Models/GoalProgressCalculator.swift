import Foundation

struct GoalProgressSnapshot: Identifiable {
    let goalID: UUID
    let name: String
    let targetAmount: Decimal
    let currentAmount: Decimal
    let remaining: Decimal
    let progress: Double
    let monthlyNeeded: Decimal?
    let monthsRemaining: Int?
    let isCompleted: Bool
    let deadline: Date?

    var id: UUID { goalID }
}

enum GoalProgressCalculator {

    static func snapshot(
        for goal: FinancialGoal,
        transactions: [Transaction],
        asOf: Date = .now,
        calendar: Calendar = .current
    ) -> GoalProgressSnapshot {
        let current = currentAmount(for: goal, transactions: transactions, asOf: asOf)
        let target = max(goal.targetAmount, 0)
        let remaining = max(target - current, 0)
        let progress: Double = {
            guard target > 0 else { return goal.isCompleted ? 1 : 0 }
            let ratio = NSDecimalNumber(decimal: current / target).doubleValue
            return min(max(ratio, 0), 1)
        }()

        let monthsRemaining = goal.deadline.map {
            monthsBetween(from: asOf, to: $0, calendar: calendar)
        }
        let monthlyNeeded: Decimal? = {
            guard let monthsRemaining, monthsRemaining > 0, remaining > 0 else { return nil }
            return remaining / Decimal(monthsRemaining)
        }()

        return GoalProgressSnapshot(
            goalID: goal.id,
            name: goal.name,
            targetAmount: target,
            currentAmount: current,
            remaining: remaining,
            progress: progress,
            monthlyNeeded: monthlyNeeded,
            monthsRemaining: monthsRemaining,
            isCompleted: goal.isCompleted || (target > 0 && current >= target),
            deadline: goal.deadline
        )
    }

    static func currentAmount(
        for goal: FinancialGoal,
        transactions: [Transaction],
        asOf: Date = .now
    ) -> Decimal {
        goal.linkedAccounts
            .filter { !$0.isArchived }
            .reduce(Decimal(0)) { partial, account in
                partial + max(account.currentBalance(considering: transactions, asOf: asOf), 0)
            }
    }

    private static func monthsBetween(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let startMonth = calendar.dateComponents([.year, .month], from: start)
        let endMonth = calendar.dateComponents([.year, .month], from: end)
        guard let startYear = startMonth.year, let startM = startMonth.month,
              let endYear = endMonth.year, let endM = endMonth.month else { return 0 }
        let diff = (endYear - startYear) * 12 + (endM - startM)
        return max(diff, 0)
    }
}
