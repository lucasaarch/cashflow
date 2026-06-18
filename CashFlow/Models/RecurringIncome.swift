import Foundation
import SwiftData

@Model
final class RecurringIncome {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    /// 1...31. Months that don't have the day get clamped to the last day.
    var dayOfMonth: Int
    var startDate: Date
    var endDate: Date?
    var isPaused: Bool
    var note: String
    var createdAt: Date
    /// When `true`, the materializer generates `Receivable` rows (manual confirmation
    /// when the money actually arrives). When `false`, generates `Transaction` rows
    /// automatically on the day — for fixed, reliable incomes (salário em débito automático).
    var requiresConfirmation: Bool = true

    var category: Category?
    var account: Account?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.recurringIncomeSource)
    var transactions: [Transaction] = []

    @Relationship(deleteRule: .nullify, inverse: \Receivable.recurringIncomeSource)
    var receivables: [Receivable] = []

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        dayOfMonth: Int,
        startDate: Date,
        endDate: Date? = nil,
        isPaused: Bool = false,
        note: String = "",
        createdAt: Date = .now,
        requiresConfirmation: Bool = true,
        category: Category? = nil,
        account: Account? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dayOfMonth = dayOfMonth
        self.startDate = startDate
        self.endDate = endDate
        self.isPaused = isPaused
        self.note = note
        self.createdAt = createdAt
        self.requiresConfirmation = requiresConfirmation
        self.category = category
        self.account = account
    }
}
