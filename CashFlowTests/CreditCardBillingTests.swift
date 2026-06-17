import XCTest
@testable import CashFlow

final class CreditCardBillingTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testClosingDateSameMonthWhenPurchaseBeforeClosing() {
        let purchase = date(2026, 6, 3)
        let closing = CreditCardBilling.closingDate(for: purchase, closingDay: 5, calendar: calendar)
        XCTAssertEqual(closing, date(2026, 6, 5))
    }

    func testClosingDateNextMonthWhenPurchaseAfterClosing() {
        let purchase = date(2026, 6, 10)
        let closing = CreditCardBilling.closingDate(for: purchase, closingDay: 5, calendar: calendar)
        XCTAssertEqual(closing, date(2026, 7, 5))
    }

    func testDueDateSameMonthWhenDueAfterClosingDay() {
        let purchase = date(2026, 6, 3)
        let due = CreditCardBilling.dueDate(for: purchase, closingDay: 5, dueDay: 12, calendar: calendar)
        XCTAssertEqual(due, date(2026, 6, 12))
    }

    func testDueDateNextMonthWhenDueBeforeClosingDay() {
        let purchase = date(2026, 6, 20)
        let due = CreditCardBilling.dueDate(for: purchase, closingDay: 25, dueDay: 5, calendar: calendar)
        XCTAssertEqual(due, date(2026, 7, 5))
    }

    func testClosingDayClampsInFebruary() {
        let purchase = date(2026, 2, 1)
        let closing = CreditCardBilling.closingDate(for: purchase, closingDay: 31, calendar: calendar)
        XCTAssertEqual(closing, date(2026, 2, 28))
    }

    func testTransactionReportingDateUsesDueDateForCard() {
        let account = makeCard(closingDay: 5, dueDay: 12)
        let purchase = date(2026, 6, 10)
        let transaction = Transaction(amount: 100, kind: .expense, occurredOn: purchase, account: account)
        XCTAssertEqual(transaction.reportingDate(calendar: calendar), date(2026, 7, 12))
    }

    func testOpenStatementWithOpeningBalanceOnly() {
        let account = makeCard(openingBalance: -1500, closingDay: 5, dueDay: 12)
        let statement = CreditCardBilling.openStatement(
            for: account,
            transactions: [],
            asOf: date(2026, 6, 10),
            calendar: calendar
        )

        XCTAssertEqual(statement.totalDebt, 1500)
        XCTAssertEqual(statement.items.count, 1)
        guard case .openingBalance(let amount) = statement.items[0] else {
            return XCTFail("Expected opening balance line")
        }
        XCTAssertEqual(amount, 1500)
    }

    func testOpenStatementWithOpeningBalanceAndCycleExpense() {
        let account = makeCard(openingBalance: -1500, closingDay: 5, dueDay: 12)
        let expense = Transaction(
            amount: 200,
            kind: .expense,
            occurredOn: date(2026, 6, 3),
            account: account
        )
        let statement = CreditCardBilling.openStatement(
            for: account,
            transactions: [expense],
            asOf: date(2026, 6, 10),
            calendar: calendar
        )

        XCTAssertEqual(statement.totalDebt, 1700)
        XCTAssertEqual(statement.items.count, 2)
        guard case .openingBalance(1500) = statement.items[0] else {
            return XCTFail("Expected opening balance first")
        }
        guard case .expense = statement.items[1] else {
            return XCTFail("Expected expense second")
        }
    }

    func testOpenStatementWithPartialPayment() {
        let account = makeCard(openingBalance: -1500, closingDay: 5, dueDay: 12)
        let payment = Transaction(
            amount: 500,
            kind: .income,
            occurredOn: date(2026, 6, 4),
            account: account
        )
        let statement = CreditCardBilling.openStatement(
            for: account,
            transactions: [payment],
            asOf: date(2026, 6, 10),
            calendar: calendar
        )

        XCTAssertEqual(statement.totalDebt, 1000)
        XCTAssertEqual(statement.items.count, 2)
        guard case .openingBalance(1500) = statement.items[0] else {
            return XCTFail("Expected opening balance first")
        }
        guard case .payment = statement.items[1] else {
            return XCTFail("Expected payment second")
        }
    }

    func testOpenStatementWithoutBillingCycleUsesSimpleDebt() {
        let account = Account(
            name: "Cartão",
            kind: .creditCard,
            colorHex: "#000000",
            symbolName: "creditcard.fill",
            sortOrder: 0,
            openingBalance: -800
        )
        let statement = CreditCardBilling.openStatement(
            for: account,
            transactions: [],
            asOf: date(2026, 6, 10),
            calendar: calendar
        )

        XCTAssertFalse(statement.hasBillingCycle)
        XCTAssertNil(statement.closingDate)
        XCTAssertEqual(statement.totalDebt, 800)
        XCTAssertEqual(statement.items.count, 1)
    }

    func testOpenStatementWhenPaidOffIsEmpty() {
        let account = makeCard(openingBalance: 0, closingDay: 5, dueDay: 12)
        let statement = CreditCardBilling.openStatement(
            for: account,
            transactions: [],
            asOf: date(2026, 6, 10),
            calendar: calendar
        )

        XCTAssertTrue(statement.isEmpty)
        XCTAssertEqual(statement.totalDebt, 0)
    }

    private func makeCard(
        openingBalance: Decimal = 0,
        closingDay: Int,
        dueDay: Int
    ) -> Account {
        Account(
            name: "Nubank",
            kind: .creditCard,
            colorHex: "#000000",
            symbolName: "creditcard.fill",
            sortOrder: 0,
            openingBalance: openingBalance,
            openingDate: date(2026, 1, 1),
            closingDay: closingDay,
            dueDay: dueDay
        )
    }
}
