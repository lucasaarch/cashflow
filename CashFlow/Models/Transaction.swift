import Foundation
import SwiftData

enum TransactionKind: String, Codable, CaseIterable {
    case expense
    case income

    var displayName: String {
        switch self {
        case .expense: return "Despesa"
        case .income: return "Receita"
        }
    }
}

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var amount: Decimal
    var kindRaw: String
    var occurredOn: Date
    var note: String
    var createdAt: Date

    var category: Category?
    var account: Account?

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        kind: TransactionKind,
        occurredOn: Date,
        note: String = "",
        createdAt: Date = .now,
        category: Category? = nil,
        account: Account? = nil
    ) {
        self.id = id
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.occurredOn = occurredOn
        self.note = note
        self.createdAt = createdAt
        self.category = category
        self.account = account
    }
}
