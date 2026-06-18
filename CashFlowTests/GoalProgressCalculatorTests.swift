import XCTest
@testable import CashFlow

final class GoalProgressCalculatorTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testLinkedAccountProgress() {
        let account = Account(
            name: "Tesouro",
            kind: .investment,
            colorHex: "#000000",
            symbolName: "chart.line.uptrend.xyaxis",
            sortOrder: 0,
            openingBalance: 4000
        )
        let goal = FinancialGoal(
            name: "Aposentadoria",
            targetAmount: 8000,
            linkedAccounts: [account]
        )

        let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: [], asOf: date(2026, 6, 1), calendar: calendar)

        XCTAssertEqual(snapshot.currentAmount, 4000)
        XCTAssertEqual(snapshot.progress, 0.5, accuracy: 0.001)
    }

    func testGoalAccountProgress() {
        let goalAccount = Account(
            name: "Caixa Viagem",
            kind: .goal,
            colorHex: "#000000",
            symbolName: "flag.fill",
            sortOrder: 0,
            openingBalance: 1500
        )
        let goal = FinancialGoal(
            name: "Viagem",
            targetAmount: 6000,
            linkedAccounts: [goalAccount]
        )

        let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: [], asOf: date(2026, 6, 1), calendar: calendar)

        XCTAssertEqual(snapshot.currentAmount, 1500)
        XCTAssertEqual(snapshot.remaining, 4500)
        XCTAssertEqual(snapshot.progress, 0.25, accuracy: 0.001)
    }

    func testMonthlyNeededWithDeadline() {
        let goalAccount = Account(
            name: "Caixa Viagem",
            kind: .goal,
            colorHex: "#000000",
            symbolName: "flag.fill",
            sortOrder: 0,
            openingBalance: 1000
        )
        let goal = FinancialGoal(
            name: "Viagem",
            targetAmount: 6000,
            deadline: date(2026, 9, 1),
            linkedAccounts: [goalAccount]
        )

        let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: [], asOf: date(2026, 6, 1), calendar: calendar)

        XCTAssertEqual(snapshot.monthsRemaining, 3)
        XCTAssertEqual(snapshot.monthlyNeeded, 5000 / 3)
    }

    func testCompletedWhenTargetReached() {
        let goalAccount = Account(
            name: "Caixa Notebook",
            kind: .goal,
            colorHex: "#000000",
            symbolName: "flag.fill",
            sortOrder: 0,
            openingBalance: 5500
        )
        let goal = FinancialGoal(
            name: "Notebook",
            targetAmount: 5000,
            linkedAccounts: [goalAccount]
        )

        let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: [], asOf: date(2026, 6, 1), calendar: calendar)

        XCTAssertTrue(snapshot.isCompleted)
        XCTAssertEqual(snapshot.progress, 1, accuracy: 0.001)
        XCTAssertEqual(snapshot.remaining, 0)
    }
}
