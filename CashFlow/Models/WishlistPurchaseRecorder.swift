import Foundation
import SwiftData

enum WishlistPurchaseRecorder {
    @discardableResult
    static func recordPurchase(
        item: WishlistItem,
        amount: Decimal,
        account: Account,
        date: Date,
        category: Category?,
        modelContext: ModelContext
    ) -> Transaction {
        let normalizedDate = Calendar.current.startOfDay(for: date)
        let trimmedNote = item.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let memo = trimmedNote.isEmpty ? item.name : "\(item.name) — \(trimmedNote)"

        let txn = Transaction(
            amount: amount,
            kind: .expense,
            occurredOn: normalizedDate,
            note: memo,
            category: category ?? item.category,
            account: account
        )
        modelContext.insert(txn)
        modelContext.delete(item)
        return txn
    }
}
