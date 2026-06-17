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

    func testManualProgressOverridesLinkedAccounts() {
        let account = Account(
            name: "CDB",
            kind: .investment,
            colorHex: "#000000",
            symbolName: "chart.line.uptrend.xyaxis",
            sortOrder: 0,
            openingBalance: 5000
        )
        let goal = FinancialGoal(
            name: "Reserva",
            targetAmount: 10_000,
            manualCurrentAmount: 3000,
            linkedAccounts: [account]
        )

        let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: [], asOf: date(2026, 6, 1), calendar: calendar)

        XCTAssertEqual(snapshot.currentAmount, 3000)
        XCTAssertEqual(snapshot.remaining, 7000)
        XCTAssertEqual(snapshot.progress, 0.3, accuracy: 0.001)
        XCTAssertTrue(snapshot.usesManualProgress)
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
        XCTAssertFalse(snapshot.usesManualProgress)
    }

    func testMonthlyNeededWithDeadline() {
        let goal = FinancialGoal(
            name: "Viagem",
            targetAmount: 6000,
            manualCurrentAmount: 1000,
            deadline: date(2026, 9, 1)
        )

        let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: [], asOf: date(2026, 6, 1), calendar: calendar)

        XCTAssertEqual(snapshot.monthsRemaining, 3)
        XCTAssertEqual(snapshot.monthlyNeeded, 5000 / 3)
    }

    func testCompletedWhenTargetReached() {
        let goal = FinancialGoal(
            name: "Notebook",
            targetAmount: 5000,
            manualCurrentAmount: 5500
        )

        let snapshot = GoalProgressCalculator.snapshot(for: goal, transactions: [], asOf: date(2026, 6, 1), calendar: calendar)

        XCTAssertTrue(snapshot.isCompleted)
        XCTAssertEqual(snapshot.progress, 1, accuracy: 0.001)
        XCTAssertEqual(snapshot.remaining, 0)
    }
}
