import XCTest
@testable import CashFlow

@MainActor
final class SpendingHistoryContextTests: XCTestCase {
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

    private func expense(_ amount: Decimal, on day: Int, month: Int = 6, year: Int = 2026, bank: Account) -> Transaction {
        Transaction(amount: amount, kind: .expense, occurredOn: date(year, month, day), account: bank)
    }

    func testAverageUsesPreviousMonthsOnly() {
        let bank = makeBank()
        var transactions: [Transaction] = []

        for month in 1...5 {
            transactions.append(expense(1000, on: 10, month: month, year: 2026, bank: bank))
        }
        transactions.append(expense(900, on: 15, month: 6, year: 2026, bank: bank))

        let history = SpendingHistoryContext.analyze(
            referenceDate: date(2026, 6, 20),
            transactions: transactions,
            lookbackMonths: 5,
            calendar: calendar,
            now: date(2026, 6, 20)
        )

        XCTAssertEqual(history.sampleCount, 5)
        XCTAssertEqual(history.averageMonthlyExpense, 1000)
        XCTAssertEqual(history.currentExpense, 900)
    }

    func testProgressTrendDetectsAboveUsualSpending() {
        let bank = makeBank()
        var transactions: [Transaction] = []

        for month in 1...3 {
            transactions.append(expense(1000, on: 28, month: month, year: 2026, bank: bank))
        }
        transactions.append(expense(900, on: 10, month: 4, year: 2026, bank: bank))

        let history = SpendingHistoryContext.analyze(
            referenceDate: date(2026, 4, 15),
            transactions: transactions,
            lookbackMonths: 6,
            calendar: calendar,
            now: date(2026, 4, 15)
        )

        XCTAssertEqual(history.progressTrend, .aboveUsual)
    }

    func testInsufficientHistoryWhenFewSamples() {
        let bank = makeBank()
        let transactions = [expense(500, on: 10, month: 6, year: 2026, bank: bank)]

        let history = SpendingHistoryContext.analyze(
            referenceDate: date(2026, 6, 15),
            transactions: transactions,
            calendar: calendar,
            now: date(2026, 6, 15)
        )

        XCTAssertEqual(history.progressTrend, .insufficientData)
    }
}

final class AIInsightCacheTests: XCTestCase {
    func testStaleAfterTwoHours() {
        let cachedAt = Date.now.addingTimeInterval(-(2 * 60 * 60 + 1))
        XCTAssertTrue(AIInsightCache.isStale(cachedAt: cachedAt))
    }

    func testFreshWithinTwoHours() {
        let cachedAt = Date.now.addingTimeInterval(-(60 * 60))
        XCTAssertFalse(AIInsightCache.isStale(cachedAt: cachedAt))
    }
}
