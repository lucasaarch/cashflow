import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            CFIconBadge(
                symbolName: transaction.category?.symbolName ?? "questionmark.circle",
                tint: rowTint,
                size: CFTheme.iconSize
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.category?.name ?? "Sem categoria")
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)

                HStack(spacing: 6) {
                    if let account = transaction.account {
                        Image(systemName: account.symbolName)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: account.colorHex))
                        Text(account.name)
                            .font(.caption)
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                    if !transaction.note.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(CFTheme.textTertiary)
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundStyle(CFTheme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 12)

            Text(formattedAmount)
                .font(CFTheme.body().weight(.medium))
                .monospacedDigit()
                .foregroundStyle(amountColor)
        }
    }

    private var rowTint: Color {
        transaction.kind == .expense ? CFTheme.expense : CFTheme.income
    }

    private var formattedAmount: String {
        let prefix = transaction.kind == .expense ? "−" : "+"
        return "\(prefix)\(transaction.amount.brl)"
    }

    private var amountColor: Color {
        transaction.kind == .expense ? CFTheme.textPrimary : CFTheme.income
    }
}
