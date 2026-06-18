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

    /// The reported regression: user has fallback budget set (R$6500) but no income
    /// realized this month. The monthly `balance` must be honest (negative if
    /// expenses already happened) — NOT inflated by the budget.
    func testBalanceIsHonestEvenWithFallbackBudget() {
        let bank = makeBank()
        let expense = Transaction(amount: 200, kind: .expense, occurredOn: date(2026, 6, 10), account: bank)

        let summary = MonthSummary(
            referenceDate: date(2026, 6, 15),
            monthlyIncomeFallback: 6500,
            transactions: [expense],
            pendingReceivables: [],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(summary.totalIncome, 0)
        XCTAssertEqual(summary.totalExpense, 200)
        XCTAssertEqual(summary.balance, -200, "balance must reflect realized cash flow, not fallback budget")
        XCTAssertTrue(summary.usesFallbackIncome)
        XCTAssertEqual(summary.expectedIncome, 6500, "expectedIncome falls back to manual budget when nothing else is registered")
    }

    /// When the user has receivables registered for the month, `expectedIncome` must
    /// pick them up and stop using the fallback budget.
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
            monthlyIncomeFallback: 1000,
            transactions: [],
            pendingReceivables: [receivable],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertFalse(summary.usesFallbackIncome, "fallback should NOT apply when data is registered")
        XCTAssertEqual(summary.pendingReceivableIncome, 6500)
        XCTAssertEqual(summary.expectedIncome, 6500, "expected = computed from receivables, not fallback")
        XCTAssertTrue(summary.hasPlanned, "pending receivable counts as planned activity")
    }

    /// `projectedBalance` projects month-end accounting for expected income and planned expense.
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
            monthlyIncomeFallback: 0,
            transactions: [realizedExpense, plannedExpense],
            pendingReceivables: [receivable],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        // expected = realized (0) + planned (0) + receivable (1500) = 1500
        // projected = 1500 − 300 (realized) − 200 (planned) = 1000
        XCTAssertEqual(summary.expectedIncome, 1500)
        XCTAssertEqual(summary.projectedBalance, 1000)
        XCTAssertEqual(summary.balance, -300, "balance stays honest: only realized")
    }

    /// `spentRatio` uses `expectedIncome` so pace is calibrated against the income
    /// realistically expected for the month, not the fallback only.
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
            monthlyIncomeFallback: 0,
            transactions: [realizedIncome, realizedExpense],
            pendingReceivables: [receivable],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        // expected = 3000 (realized) + 0 (planned) + 3000 (receivable) = 6000
        // spentRatio = 1500 / 6000 = 0.25
        XCTAssertEqual(summary.expectedIncome, 6000)
        XCTAssertEqual(summary.spentRatio, 0.25, accuracy: 0.001)
    }

    /// Pending receivables outside the reference month should NOT inflate `expectedIncome`.
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
            monthlyIncomeFallback: 1000,
            transactions: [],
            pendingReceivables: [nextMonthReceivable],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(summary.pendingReceivableIncome, 0)
        XCTAssertTrue(summary.usesFallbackIncome)
        XCTAssertEqual(summary.expectedIncome, 1000)
    }
}
