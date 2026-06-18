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
    /// Non-nil when this transaction is one leg of an internal transfer (e.g. bank ↔ investment).
    /// Both legs share the same UUID so the dashboard can exclude them from expense/income totals.
    var transferGroupID: UUID?
    /// 1...N when this is part of a credit-card installment plan; 0 otherwise.
    var installmentIndex: Int = 0

    var category: Category?
    var account: Account?
    var installmentPlan: InstallmentPlan?
    var recurringSource: RecurringExpense?
    var recurringIncomeSource: RecurringIncome?

    var kind: TransactionKind {
        get { TransactionKind(rawValue: kindRaw) ?? .expense }
        set { kindRaw = newValue.rawValue }
    }

    var isTransfer: Bool { transferGroupID != nil }
    var isInstallment: Bool { installmentIndex > 0 }
    var isRecurring: Bool { recurringSource != nil }

    init(
        id: UUID = UUID(),
        amount: Decimal,
        kind: TransactionKind,
        occurredOn: Date,
        note: String = "",
        createdAt: Date = .now,
        category: Category? = nil,
        account: Account? = nil,
        transferGroupID: UUID? = nil,
        installmentPlan: InstallmentPlan? = nil,
        installmentIndex: Int = 0
    ) {
        self.id = id
        self.amount = amount
        self.kindRaw = kind.rawValue
        self.occurredOn = occurredOn
        self.note = note
        self.createdAt = createdAt
        self.category = category
        self.account = account
        self.transferGroupID = transferGroupID
        self.installmentPlan = installmentPlan
        self.installmentIndex = installmentIndex
    }
}
