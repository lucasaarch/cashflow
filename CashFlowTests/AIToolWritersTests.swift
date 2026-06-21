import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class AIToolWritersTests: XCTestCase {
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = ModelContainerFactory.make(inMemory: true)
        context = container.mainContext
    }

    private var container: ModelContainer!

    func testPurchaseWishlistItemCreatesTransactionAndRemovesItem() throws {
        let account = Account(
            name: "Banco",
            kind: .bank,
            colorHex: "#F97316",
            symbolName: "building.columns.fill",
            sortOrder: 0
        )
        context.insert(account)
        let item = WishlistItem(name: "Fone", estimatedAmount: 500, priority: .medium)
        context.insert(item)
        try context.save()

        let toolContext = makeToolContext()
        let txnCountBefore = (try? context.fetch(FetchDescriptor<Transaction>()))?.count ?? 0
        let result = try AIToolWriters.execute(
            toolName: "purchase_wishlist_item",
            args: ["item_name": "Fone", "account": "Banco"],
            context: toolContext
        )
        XCTAssertTrue(result.ok)

        let remaining = try context.fetch(FetchDescriptor<WishlistItem>())
        XCTAssertFalse(remaining.contains(where: { $0.name == "Fone" }))

        let txnCountAfter = try context.fetch(FetchDescriptor<Transaction>()).count
        XCTAssertEqual(txnCountAfter, txnCountBefore + 1)
    }

    func testCancelBillMarksCancelled() throws {
        let bill = Bill(name: "Internet", amount: 120, dueDate: .now, category: nil, account: nil)
        context.insert(bill)
        try context.save()

        let toolContext = makeToolContext(bills: [bill])
        let result = try AIToolWriters.execute(
            toolName: "cancel_bill",
            args: ["bill": "Internet"],
            context: toolContext
        )
        XCTAssertTrue(result.ok)
        XCTAssertEqual(bill.status, .cancelled)
    }

    func testCreateGoalCreatesDedicatedAccount() throws {
        let toolContext = makeToolContext()
        let result = try AIToolWriters.execute(
            toolName: "create_goal",
            args: ["name": "Viagem", "target_amount": 5000],
            context: toolContext
        )
        XCTAssertTrue(result.ok)

        let goals = try context.fetch(FetchDescriptor<FinancialGoal>())
        XCTAssertEqual(goals.count, 1)
        XCTAssertEqual(goals.first?.name, "Viagem")
        XCTAssertEqual(goals.first?.linkedAccounts.count, 1)
        XCTAssertEqual(goals.first?.linkedAccounts.first?.kind, .goal)
    }

    func testCreateRecurringExpenseCreatesRule() throws {
        let account = Account(
            name: "Banco",
            kind: .bank,
            colorHex: "#F97316",
            symbolName: "building.columns.fill",
            sortOrder: 0
        )
        let category = Category(name: "Moradia", symbolName: "house.fill", kind: .expense, sortOrder: 0)
        context.insert(account)
        context.insert(category)
        try context.save()

        let toolContext = makeToolContext()
        let result = try AIToolWriters.execute(
            toolName: "create_recurring_expense",
            args: [
                "name": "Aluguel",
                "amount": 1800,
                "day_of_month": 5,
                "account": "Banco",
                "category": "Moradia"
            ],
            context: toolContext
        )
        XCTAssertTrue(result.ok)

        let rules = try context.fetch(FetchDescriptor<RecurringExpense>())
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules.first?.name, "Aluguel")
    }

    func testUpdateTransactionChangesAmount() throws {
        let account = Account(
            name: "Banco",
            kind: .bank,
            colorHex: "#F97316",
            symbolName: "building.columns.fill",
            sortOrder: 0
        )
        context.insert(account)
        let txn = Transaction(amount: 120, kind: .expense, occurredOn: .now, note: "Mercado", account: account)
        context.insert(txn)
        try context.save()

        let toolContext = makeToolContext()
        let result = try AIToolWriters.execute(
            toolName: "update_transaction",
            args: [
                "transaction_id": txn.id.uuidString,
                "amount": 130
            ],
            context: toolContext
        )
        XCTAssertTrue(result.ok)
        XCTAssertEqual(txn.amount, 130)
    }

    func testDeleteTransactionBlockedWhenLinkedToPaidBill() throws {
        let account = Account(
            name: "Banco",
            kind: .bank,
            colorHex: "#F97316",
            symbolName: "building.columns.fill",
            sortOrder: 0
        )
        context.insert(account)
        let txn = Transaction(amount: 120, kind: .expense, occurredOn: .now, note: "Internet", account: account)
        context.insert(txn)
        let bill = Bill(
            name: "Internet",
            amount: 120,
            dueDate: .now,
            status: .paid,
            paidOn: .now,
            paidTransactionID: txn.id,
            category: nil,
            account: account
        )
        context.insert(bill)
        try context.save()

        let toolContext = makeToolContext(bills: [bill])
        XCTAssertThrowsError(
            try AIToolWriters.execute(
                toolName: "delete_transaction",
                args: ["transaction_id": txn.id.uuidString],
                context: toolContext
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("Internet"))
        }
    }

    func testUpdateBillSummaryShowsAmountChange() throws {
        let bill = Bill(name: "Internet", amount: 120, dueDate: .now, category: nil, account: nil)
        context.insert(bill)
        try context.save()

        let toolContext = makeToolContext(bills: [bill])
        let summary = try AIToolWriters.buildSummary(
            toolName: "update_bill",
            args: ["bill": "Internet", "amount": 130],
            context: toolContext
        )
        XCTAssertTrue(summary.contains("120"))
        XCTAssertTrue(summary.contains("130"))
    }

    private func makeToolContext(
        bills: [Bill] = [],
        receivables: [Receivable] = []
    ) -> AIToolContext {
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let categories = (try? context.fetch(FetchDescriptor<CashFlow.Category>())) ?? []
        let wishlistItems = (try? context.fetch(FetchDescriptor<WishlistItem>())) ?? []
        return AIToolContext(
            modelContext: context,
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            receivables: receivables,
            goals: [],
            recurringExpenses: [],
            recurringIncomes: [],
            categories: categories,
            wishlistItems: wishlistItems
        )
    }
}
