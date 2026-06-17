import Foundation
import SwiftData

@Model
final class FinancialGoal {
    @Attribute(.unique) var id: UUID
    var name: String
    var targetAmount: Decimal
    /// When non-nil, overrides linked-account balances for progress.
    var manualCurrentAmount: Decimal?
    var deadline: Date?
    var symbolName: String
    var colorHex: String
    var notes: String
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Account.linkedGoals)
    var linkedAccounts: [Account] = []

    var usesManualProgress: Bool { manualCurrentAmount != nil }

    init(
        id: UUID = UUID(),
        name: String,
        targetAmount: Decimal,
        manualCurrentAmount: Decimal? = nil,
        deadline: Date? = nil,
        symbolName: String = "flag.fill",
        colorHex: String = "#6366F1",
        notes: String = "",
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        createdAt: Date = .now,
        linkedAccounts: [Account] = []
    ) {
        self.id = id
        self.name = name
        self.targetAmount = targetAmount
        self.manualCurrentAmount = manualCurrentAmount
        self.deadline = deadline
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.notes = notes
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.createdAt = createdAt
        self.linkedAccounts = linkedAccounts
    }
}
