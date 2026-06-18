import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class WishlistPurchaseRecorderTests: XCTestCase {
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = PreviewData.container
        context = container.mainContext
    }

    private var container: ModelContainer!

    func testRecordPurchaseCreatesTransactionAndDeletesItem() throws {
        let account = Account(
            name: "Banco",
            kind: .bank,
            colorHex: "#F97316",
            symbolName: "building.columns.fill",
            sortOrder: 0
        )
        let category = Category(name: "Roupas", symbolName: "tshirt.fill", kind: .expense, sortOrder: 0)
        context.insert(account)
        context.insert(category)

        let item = WishlistItem(name: "Calça", estimatedAmount: 250, priority: .medium, category: category)
        context.insert(item)
        try context.save()

        let itemID = item.id
        let txn = WishlistPurchaseRecorder.recordPurchase(
            item: item,
            amount: 280,
            account: account,
            date: .now,
            category: category,
            modelContext: context
        )
        try context.save()

        XCTAssertEqual(txn.kind, TransactionKind.expense)
        XCTAssertEqual(txn.amount, 280)
        XCTAssertEqual(txn.account?.id, account.id)
        XCTAssertEqual(txn.category?.id, category.id)
        XCTAssertTrue(txn.note.contains("Calça"))

        let remaining = try context.fetch(FetchDescriptor<WishlistItem>())
        XCTAssertFalse(remaining.contains(where: { $0.id == itemID }))
    }
}
