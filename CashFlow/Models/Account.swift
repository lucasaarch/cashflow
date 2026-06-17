import Foundation
import SwiftData

enum AccountKind: String, Codable, CaseIterable {
    case bank
    case creditCard
    case investment

    var displayName: String {
        switch self {
        case .bank:       return "Banco"
        case .creditCard: return "Cartão"
        case .investment: return "Investimento"
        }
    }

    /// Liquid kinds count toward your "available money" total.
    /// Cards represent debt; investments represent allocated, non-liquid funds.
    var isLiquid: Bool {
        switch self {
        case .bank:                    return true
        case .creditCard, .investment: return false
        }
    }

    var defaultSymbolName: String {
        switch self {
        case .bank:       return "building.columns.fill"
        case .creditCard: return "creditcard.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
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
    /// Day of month the statement closes (1…31). `0` = unset (bank accounts).
    var closingDay: Int = 0
    /// Day of month payment is due (1…31). `0` = unset.
    var dueDay: Int = 0

    @Relationship(deleteRule: .nullify, inverse: \Transaction.account)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .nullify, inverse: \Bill.account)
    var payableBills: [Bill] = []

    @Relationship(deleteRule: .nullify, inverse: \Bill.cardStatementSource)
    var statementBills: [Bill] = []

    var linkedGoals: [FinancialGoal] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.account)
    var recurringExpenses: [RecurringExpense] = []

    @Relationship(deleteRule: .nullify, inverse: \InstallmentPlan.account)
    var installmentPlans: [InstallmentPlan] = []

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
        openingDate: Date = .now,
        closingDay: Int = 0,
        dueDay: Int = 0
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
        self.closingDay = closingDay
        self.dueDay = dueDay
    }
}

extension Account {
    func currentBalance(considering transactions: [Transaction], asOf: Date = .now) -> Decimal {
        let net = transactions
            .filter { $0.account?.id == id && $0.occurredOn >= openingDate && $0.occurredOn <= asOf }
            .reduce(Decimal(0)) { partial, txn in
                switch txn.kind {
                case .expense: return partial - txn.amount
                case .income:  return partial + txn.amount
                }
            }
        return openingBalance + net
    }
}
