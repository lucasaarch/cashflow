import Foundation
import SwiftData

enum ReceivableStatus: String, Codable, CaseIterable {
    case pending
    case received
    case cancelled
}

@Model
final class Receivable {
    @Attribute(.unique) var id: UUID
    var name: String
    var amount: Decimal
    var expectedDate: Date
    var note: String
    var statusRaw: String
    var receivedOn: Date?
    /// UUID of the `Transaction` generated when this Receivable was confirmed. Mirrors the
    /// pattern used by `Bill.paidTransactionID` to avoid forcing a SwiftData relationship.
    var receivedTransactionID: UUID?
    var createdAt: Date

    var category: Category?
    var account: Account?

    var status: ReceivableStatus {
        get { ReceivableStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var isPending: Bool { status == .pending }
    var isReceived: Bool { status == .received }

    func isLate(now: Date = .now) -> Bool {
        status == .pending && expectedDate < now
    }

    init(
        id: UUID = UUID(),
        name: String,
        amount: Decimal,
        expectedDate: Date,
        note: String = "",
        status: ReceivableStatus = .pending,
        receivedOn: Date? = nil,
        receivedTransactionID: UUID? = nil,
        createdAt: Date = .now,
        category: Category? = nil,
        account: Account? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.expectedDate = expectedDate
        self.note = note
        self.statusRaw = status.rawValue
        self.receivedOn = receivedOn
        self.receivedTransactionID = receivedTransactionID
        self.createdAt = createdAt
        self.category = category
        self.account = account
    }
}
