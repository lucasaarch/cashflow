import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class CardStatementMaterializerTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testCreatesBillForClosedStatement() throws {
        let context = try makeContext()
        let card = makeCard(closingDay: 5, dueDay: 12)
        context.insert(card)

        let expense = Transaction(
            amount: 250,
            kind: .expense,
            occurredOn: date(2026, 5, 3),
            account: card
        )
        context.insert(expense)

        CardStatementMaterializer.materializeAll(
            context: context,
            now: date(2026, 5, 10),
            calendar: calendar
        )

        let bills = try context.fetch(FetchDescriptor<Bill>())
        XCTAssertEqual(bills.count, 1)
        XCTAssertEqual(bills[0].amount, 250)
        XCTAssertEqual(bills[0].cardStatementSource?.id, card.id)
        XCTAssertEqual(bills[0].dueDate, date(2026, 5, 12))
        XCTAssertTrue(bills[0].isPending)
        XCTAssertTrue(bills[0].name.contains(card.name))
    }

    func testSkipsOpenCycle() throws {
        let context = try makeContext()
        let card = makeCard(closingDay: 5, dueDay: 12)
        context.insert(card)

        let expense = Transaction(
            amount: 100,
            kind: .expense,
            occurredOn: date(2026, 6, 3),
            account: card
        )
        context.insert(expense)

        CardStatementMaterializer.materializeAll(
            context: context,
            now: date(2026, 6, 4),
            calendar: calendar
        )

        let bills = try context.fetch(FetchDescriptor<Bill>())
        XCTAssertTrue(bills.isEmpty)
    }

    func testIsIdempotentForSameClosingDate() throws {
        let context = try makeContext()
        let card = makeCard(closingDay: 5, dueDay: 12)
        context.insert(card)

        let expense = Transaction(
            amount: 80,
            kind: .expense,
            occurredOn: date(2026, 5, 20),
            account: card
        )
        context.insert(expense)

        let now = date(2026, 6, 10)
        CardStatementMaterializer.materializeAll(context: context, now: now, calendar: calendar)
        CardStatementMaterializer.materializeAll(context: context, now: now, calendar: calendar)

        let bills = try context.fetch(FetchDescriptor<Bill>())
        XCTAssertEqual(bills.count, 1)
    }

    func testSkipsCycleWithNoNetDebt() throws {
        let context = try makeContext()
        let card = makeCard(closingDay: 5, dueDay: 12)
        context.insert(card)

        let expense = Transaction(
            amount: 200,
            kind: .expense,
            occurredOn: date(2026, 5, 3),
            account: card
        )
        let payment = Transaction(
            amount: 200,
            kind: .income,
            occurredOn: date(2026, 5, 4),
            account: card
        )
        context.insert(expense)
        context.insert(payment)

        CardStatementMaterializer.materializeAll(
            context: context,
            now: date(2026, 5, 10),
            calendar: calendar
        )

        let bills = try context.fetch(FetchDescriptor<Bill>())
        XCTAssertTrue(bills.isEmpty)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Account.self, Transaction.self, Bill.self, Category.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func makeCard(closingDay: Int, dueDay: Int) -> Account {
        Account(
            name: "Nubank",
            kind: .creditCard,
            colorHex: "#000000",
            symbolName: "creditcard.fill",
            sortOrder: 0,
            openingDate: date(2026, 1, 1),
            closingDay: closingDay,
            dueDay: dueDay
        )
    }
}
