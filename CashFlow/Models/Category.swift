import Foundation
import SwiftData

enum CategoryKind: String, Codable, CaseIterable {
    case expense
    case income
}

@Model
final class Category {
    @Attribute(.unique) var id: UUID
    var name: String
    var symbolName: String
    var kindRaw: String
    var sortOrder: Int
    var isArchived: Bool
    var seeded: Bool
    var monthlyBudgetMinorUnits: Int64?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .nullify, inverse: \Bill.category)
    var bills: [Bill] = []

    @Relationship(deleteRule: .nullify, inverse: \RecurringExpense.category)
    var recurringExpenses: [RecurringExpense] = []

    @Relationship(deleteRule: .nullify, inverse: \InstallmentPlan.category)
    var installmentPlans: [InstallmentPlan] = []

    var kind: CategoryKind {
        get { CategoryKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        symbolName: String,
        kind: CategoryKind,
        sortOrder: Int,
        isArchived: Bool = false,
        seeded: Bool = false,
        monthlyBudgetMinorUnits: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.kindRaw = kind.rawValue
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.seeded = seeded
        self.monthlyBudgetMinorUnits = monthlyBudgetMinorUnits
    }

    var monthlyBudget: Decimal? {
        get {
            guard let monthlyBudgetMinorUnits else { return nil }
            return Decimal(monthlyBudgetMinorUnits) / 100
        }
        set {
            if let newValue {
                monthlyBudgetMinorUnits = newValue.minorUnits
            } else {
                monthlyBudgetMinorUnits = nil
            }
        }
    }
}
