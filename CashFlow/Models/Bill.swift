import Foundation
import SwiftData

enum BillStatus: String, Codable, CaseIterable {
    case pending
    case paid
    case cancelled
}

@Model
final class Bill {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var dueDate: Date
    var note: String
    var statusRaw: String
    var paidOn: Date?
    /// UUID of the `Transaction` generated when this Bill was paid. Used to find/edit/delete
    /// the linked transaction without forcing a SwiftData relationship (which would complicate
    /// the inverse rules on `Transaction`).
    var paidTransactionID: UUID?
    var createdAt: Date

    var category: Category?
    var account: Account?
    var recurringSource: RecurringExpense?
    /// Non-nil when this Bill represents a closed credit-card statement.
    var cardStatementSource: Account?
    /// Closing date of the card statement that generated this Bill. Used as idempotency key.
    var cardStatementClosingDate: Date?

    var isCardStatement: Bool { cardStatementSource != nil }

    var status: BillStatus {
        get { BillStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var isPending: Bool { status == .pending }
    var isPaid: Bool { status == .paid }

    func isOverdue(now: Date = .now) -> Bool {
        status == .pending && dueDate < now
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        dueDate: Date,
        note: String = "",
        status: BillStatus = .pending,
        paidOn: Date? = nil,
        paidTransactionID: UUID? = nil,
        createdAt: Date = .now,
        category: Category? = nil,
        account: Account? = nil,
        recurringSource: RecurringExpense? = nil,
        cardStatementSource: Account? = nil,
        cardStatementClosingDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.dueDate = dueDate
        self.note = note
        self.statusRaw = status.rawValue
        self.paidOn = paidOn
        self.paidTransactionID = paidTransactionID
        self.createdAt = createdAt
        self.category = category
        self.account = account
        self.recurringSource = recurringSource
        self.cardStatementSource = cardStatementSource
        self.cardStatementClosingDate = cardStatementClosingDate
    }
}
