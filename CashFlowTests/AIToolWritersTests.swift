import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class AIToolWritersTests: XCTestCase {
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PreviewData.container
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

    private func makeToolContext() -> AIToolContext {
        let transactions = (try? context.fetch(FetchDescriptor<Transaction>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<Account>())) ?? []
        let wishlistItems = (try? context.fetch(FetchDescriptor<WishlistItem>())) ?? []
        return AIToolContext(
            modelContext: context,
            transactions: transactions,
            accounts: accounts,
            bills: [],
            receivables: [],
            goals: [],
            recurringExpenses: [],
            recurringIncomes: [],
            categories: [],
            wishlistItems: wishlistItems,
            monthlyIncomeCents: 500_000
        )
    }
}
