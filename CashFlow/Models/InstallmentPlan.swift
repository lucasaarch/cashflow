import Foundation
import SwiftData

@Model
final class InstallmentPlan {
    @Attribute(.unique) var id: UUID
    var purchaseDate: Date
    var totalAmount: Decimal
    var installmentCount: Int
    var note: String
    var createdAt: Date

    var account: Account?
    var category: Category?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.installmentPlan)
    var installments: [Transaction] = []

    init(
        id: UUID = UUID(),
        purchaseDate: Date,
        totalAmount: Decimal,
        installmentCount: Int,
        note: String = "",
        createdAt: Date = .now,
        account: Account? = nil,
        category: Category? = nil
    ) {
        self.id = id
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.installmentCount = installmentCount
        self.note = note
        self.createdAt = createdAt
        self.account = account
        self.category = category
    }
}
