import Foundation

enum AIContextBuilder {
    static let maxCharacters = 12_000

    static func financialSnapshot(
        transactions: [Transaction],
        accounts: [Account],
        monthlyIncomeCents: Int,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let budget = Decimal(monthlyIncomeCents) / 100
        let cutoff = calendar.date(byAdding: .day, value: -90, to: referenceDate) ?? referenceDate
        let recent = transactions
            .filter { $0.occurredOn >= cutoff }
            .sorted { $0.occurredOn > $1.occurredOn }

        var lines: [String] = []
        lines.append("Mês de referência: \(referenceDate.formatted(.dateTime.month(.wide).year()))")
        lines.append("Orçamento mensal: \(budget.brl)")
        lines.append("Saldos por conta:")
        for account in accounts where !account.isArchived {
            let balance = accountBalance(account, transactions: transactions)
            lines.append("- \(account.name): \(balance.brl)")
        }
        lines.append("Lançamentos (últimos 90 dias):")

        var transactionLines = recent.map(transactionLine)
        var body = lines.joined(separator: "\n") + "\n"

        while !transactionLines.isEmpty {
            let candidate = body + transactionLines.joined(separator: "\n")
            if candidate.count <= maxCharacters { break }
            transactionLines.removeLast()
        }

        if transactionLines.isEmpty, let last = recent.last {
            transactionLines = [transactionLine(last)]
        }

        body += transactionLines.joined(separator: "\n")
        return body
    }

    private static func accountBalance(_ account: Account, transactions: [Transaction]) -> Decimal {
        let delta = transactions
            .filter { $0.account?.id == account.id }
            .reduce(Decimal(0)) { partial, tx in
                partial + (tx.kind == .income ? tx.amount : -tx.amount)
            }
        return account.openingBalance + delta
    }

    private static func transactionLine(_ transaction: Transaction) -> String {
        let category = transaction.category?.name ?? "Sem categoria"
        let account = transaction.account?.name ?? "Sem conta"
        let date = transaction.occurredOn.formatted(date: .abbreviated, time: .omitted)
        let note = transaction.note.isEmpty ? "" : " | nota: \(transaction.note)"
        return "- \(date) | \(transaction.kind.rawValue) | \(transaction.amount.brl) | \(category) | \(account)\(note)"
    }
}
