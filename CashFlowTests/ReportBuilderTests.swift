import XCTest
@testable import CashFlow

final class ReportBuilderTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testCashFlowSeriesCountsMonths() {
        let bank = makeBank()
        let txns = [
            Transaction(amount: 5000, kind: .income, occurredOn: date(2026, 4, 10), account: bank),
            Transaction(amount: 1200, kind: .expense, occurredOn: date(2026, 5, 5), account: bank),
            Transaction(amount: 800, kind: .expense, occurredOn: date(2026, 6, 2), account: bank)
        ]

        let builder = ReportBuilder(
            referenceDate: date(2026, 6, 15),
            period: .threeMonths,
            transactions: txns,
            accounts: [bank],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(builder.cashFlowSeries.count, 3)
        XCTAssertEqual(builder.cashFlowSeries[0].income, 5000)
        XCTAssertEqual(builder.cashFlowSeries[1].expense, 1200)
        XCTAssertEqual(builder.cashFlowSeries[2].expense, 800)
    }

    func testNetWorthUsesBalancesAsOfMonthEnd() {
        let bank = makeBank(openingBalance: 1000)
        let investment = Account(
            name: "CDB",
            kind: .investment,
            colorHex: "#000000",
            symbolName: "chart.line.uptrend.xyaxis",
            sortOrder: 1,
            openingBalance: 2000,
            openingDate: date(2026, 1, 1)
        )
        let txns = [
            Transaction(amount: 500, kind: .income, occurredOn: date(2026, 5, 10), account: bank)
        ]

        let builder = ReportBuilder(
            referenceDate: date(2026, 6, 15),
            period: .threeMonths,
            transactions: txns,
            accounts: [bank, investment],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        let last = builder.netWorthSeries.last!
        XCTAssertEqual(last.liquid, 1500)
        XCTAssertEqual(last.invested, 2000)
        XCTAssertEqual(last.netWorth, 3500)
    }

    func testNetWorthIncludesGoalReservedBalance() {
        let bank = makeBank(openingBalance: 1000)
        let goal = Account(
            name: "Viagem",
            kind: .goal,
            colorHex: "#000000",
            symbolName: "flag.fill",
            sortOrder: 1,
            openingBalance: 800,
            openingDate: date(2026, 1, 1)
        )

        let builder = ReportBuilder(
            referenceDate: date(2026, 6, 15),
            period: .threeMonths,
            transactions: [],
            accounts: [bank, goal],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        let last = builder.netWorthSeries.last!
        XCTAssertEqual(last.invested, 800)
        XCTAssertEqual(last.netWorth, 1800)
    }

    func testMonthComparisonDelta() {
        let bank = makeBank()
        let txns = [
            Transaction(amount: 3000, kind: .income, occurredOn: date(2026, 5, 5), account: bank),
            Transaction(amount: 1000, kind: .expense, occurredOn: date(2026, 5, 10), account: bank),
            Transaction(amount: 4000, kind: .income, occurredOn: date(2026, 6, 5), account: bank),
            Transaction(amount: 1500, kind: .expense, occurredOn: date(2026, 6, 8), account: bank)
        ]

        let builder = ReportBuilder(
            referenceDate: date(2026, 6, 15),
            period: .threeMonths,
            transactions: txns,
            accounts: [bank],
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        let comparison = builder.monthComparison
        XCTAssertEqual(comparison.currentIncome, 4000)
        XCTAssertEqual(comparison.previousExpense, 1000)
        XCTAssertEqual(comparison.expenseDeltaPercent ?? 0, 50, accuracy: 0.1)
    }

    private func makeBank(openingBalance: Decimal = 0) -> Account {
        Account(
            name: "Banco",
            kind: .bank,
            colorHex: "#000000",
            symbolName: "building.columns.fill",
            sortOrder: 0,
            openingBalance: openingBalance,
            openingDate: date(2026, 1, 1)
        )
    }
}
