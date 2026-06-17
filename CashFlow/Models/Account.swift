import Foundation
import SwiftData

enum AccountKind: String, Codable, CaseIterable {
    case bank
    case creditCard

    var displayName: String {
        switch self {
        case .bank:       return "Banco"
        case .creditCard: return "Cartão"
        }
    }

    /// Liquid kinds count toward your "available money" total.
    /// Cards represent debt, not liquid funds.
    var isLiquid: Bool {
        switch self {
        case .bank:       return true
        case .creditCard: return false
        }
    }

    var defaultSymbolName: String {
        switch self {
        case .bank:       return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        }
    }
}

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRaw: String
    var colorHex: String
    var symbolName: String
    var isArchived: Bool
    var sortOrder: Int
    var openingBalance: Decimal
    var openingDate: Date

    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    var kind: AccountKind {
        get {
            // Map legacy raw values transparently so existing data keeps working
            // when the enum is refactored (no SwiftData migration needed).
            switch kindRaw {
            case "checking", "cash": return .bank
            case "externalDebt":     return .creditCard
            default: return AccountKind(rawValue: kindRaw) ?? .bank
            }
        }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        kind: AccountKind,
        colorHex: String,
        symbolName: String,
        sortOrder: Int,
        isArchived: Bool = false,
        openingBalance: Decimal = 0,
        openingDate: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kindRaw = kind.rawValue
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.openingBalance = openingBalance
        self.openingDate = openingDate
    }
}

extension Account {
    func currentBalance(considering transactions: [Transaction]) -> Decimal {
        let net = transactions
            .filter { $0.account?.id == id && $0.occurredOn >= openingDate }
            .reduce(Decimal(0)) { partial, txn in
                switch txn.kind {
                case .expense: return partial - txn.amount
                case .income:  return partial + txn.amount
                }
            }
        return openingBalance + net
    }
}
