import SwiftUI

struct TransactionRow: View {
    let transaction: Transaction

    var body: some View {
        HStack(spacing: 14) {
            iconBadge

            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.category?.name ?? "Sem categoria")
                    .font(.body)
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    if let account = transaction.account {
                        Image(systemName: account.symbolName)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: account.colorHex))
                        Text(account.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !transaction.note.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(transaction.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 12)

            Text(formattedAmount)
                .font(.body.monospacedDigit().weight(.medium))
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 6)
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 34, height: 34)
            Image(systemName: transaction.category?.symbolName ?? "questionmark.circle")
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }

    private var tint: Color {
        transaction.kind == .expense ? .red : .green
    }

    private var formattedAmount: String {
        let prefix = transaction.kind == .expense ? "−" : "+"
        return "\(prefix)\(transaction.amount.brl)"
    }

    private var amountColor: Color {
        transaction.kind == .expense ? .primary : .green
    }
}
