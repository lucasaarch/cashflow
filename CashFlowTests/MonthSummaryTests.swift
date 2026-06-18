import XCTest
@testable import CashFlow

final class MonthSummaryTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeBank() -> Account {
        Account(
            name: "Banco",
            kind: .bank,
            colorHex: "#000000",
            symbolName: "building.columns.fill",
            sortOrder: 0,
            openingBalance: 0,
            openingDate: date(2026, 1, 1)
        )
    }

    func testBalanceIsHonestWithoutRegisteredIncome() {
        let bank = makeBank()
        let expense = Transaction(amount: 200, kind: .expense, occurredOn: date(2026, 6, 10), account: bank)

        let summary = MonthSummary(
            referenceDate: date(2026, 6, 15),
            transactions: [expense],
            pendingReceivables: [],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(summary.totalIncome, 0)
        XCTAssertEqual(summary.totalExpense, 200)
        XCTAssertEqual(summary.balance, -200)
        XCTAssertEqual(summary.expectedIncome, 0)
    }

    func testExpectedIncomeUsesReceivables() {
        let bank = makeBank()
        let receivable = Receivable(
            name: "Salário",
            amount: 6500,
            expectedDate: date(2026, 6, 20),
            status: .pending,
            account: bank
        )

        let summary = MonthSummary(
            referenceDate: date(2026, 6, 15),
            transactions: [],
            pendingReceivables: [receivable],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(summary.pendingReceivableIncome, 6500)
        XCTAssertEqual(summary.expectedIncome, 6500)
        XCTAssertTrue(summary.hasPlanned)
    }

    func testProjectedBalanceCombinesExpectedAndPlanned() {
        let bank = makeBank()
        let realizedExpense = Transaction(amount: 300, kind: .expense, occurredOn: date(2026, 6, 10), account: bank)
        let plannedExpense = Transaction(amount: 200, kind: .expense, occurredOn: date(2026, 6, 25), account: bank)
        let receivable = Receivable(
            name: "Freela",
            amount: 1500,
            expectedDate: date(2026, 6, 28),
            status: .pending,
            account: bank
        )

        let summary = MonthSummary(
            referenceDate: date(2026, 6, 15),
            transactions: [realizedExpense, plannedExpense],
            pendingReceivables: [receivable],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(summary.expectedIncome, 1500)
        XCTAssertEqual(summary.projectedBalance, 1000)
        XCTAssertEqual(summary.balance, -300)
    }

    func testSpentRatioUsesExpectedIncome() {
        let bank = makeBank()
        let realizedIncome = Transaction(amount: 3000, kind: .income, occurredOn: date(2026, 6, 5), account: bank)
        let realizedExpense = Transaction(amount: 1500, kind: .expense, occurredOn: date(2026, 6, 10), account: bank)
        let receivable = Receivable(
            name: "Parte 2 do salário",
            amount: 3000,
            expectedDate: date(2026, 6, 20),
            status: .pending,
            account: bank
        )

        let summary = MonthSummary(
            referenceDate: date(2026, 6, 15),
            transactions: [realizedIncome, realizedExpense],
            pendingReceivables: [receivable],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(summary.expectedIncome, 6000)
        XCTAssertEqual(summary.spentRatio, 0.25, accuracy: 0.001)
    }

    func testReceivablesOutsideMonthAreIgnored() {
        let bank = makeBank()
        let nextMonthReceivable = Receivable(
            name: "Salário julho",
            amount: 6500,
            expectedDate: date(2026, 7, 5),
            status: .pending,
            account: bank
        )

        let summary = MonthSummary(
            referenceDate: date(2026, 6, 15),
            transactions: [],
            pendingReceivables: [nextMonthReceivable],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(summary.pendingReceivableIncome, 0)
        XCTAssertEqual(summary.expectedIncome, 0)
    }
}
