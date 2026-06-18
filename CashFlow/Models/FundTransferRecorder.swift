import Foundation
import SwiftData

enum FundTransferDirection: String, CaseIterable, Identifiable {
    case deposit
    case withdraw

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deposit: return "Aportar"
        case .withdraw: return "Resgatar"
        }
    }

    func actionLabel(for fundKind: AccountKind) -> String {
        switch (self, fundKind) {
        case (.deposit, .investment): return "Aporte"
        case (.withdraw, .investment): return "Resgate"
        case (.deposit, .goal): return "Depósito em meta"
        case (.withdraw, .goal): return "Retirada de meta"
        default: return "Transferência"
        }
    }
}

enum FundTransferRecorder {
    static func record(
        in context: ModelContext,
        direction: FundTransferDirection,
        amount: Decimal,
        occurredOn: Date,
        bankAccount: Account,
        fundAccount: Account,
        note: String = ""
    ) {
        guard amount > 0,
              fundAccount.kind == .investment || fundAccount.kind == .goal
        else { return }

        let groupID = UUID()
        let normalizedDate = Calendar.current.startOfDay(for: occurredOn)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = direction.actionLabel(for: fundAccount.kind)
        let memo = trimmedNote.isEmpty ? "\(label) \(fundAccount.name)" : trimmedNote

        switch direction {
        case .deposit:
            context.insert(Transaction(
                amount: amount,
                kind: .expense,
                occurredOn: normalizedDate,
                note: memo,
                account: bankAccount,
                transferGroupID: groupID
            ))
            context.insert(Transaction(
                amount: amount,
                kind: .income,
                occurredOn: normalizedDate,
                note: memo,
                account: fundAccount,
                transferGroupID: groupID
            ))

        case .withdraw:
            context.insert(Transaction(
                amount: amount,
                kind: .expense,
                occurredOn: normalizedDate,
                note: memo,
                account: fundAccount,
                transferGroupID: groupID
            ))
            context.insert(Transaction(
                amount: amount,
                kind: .income,
                occurredOn: normalizedDate,
                note: memo,
                account: bankAccount,
                transferGroupID: groupID
            ))
        }
    }
}
