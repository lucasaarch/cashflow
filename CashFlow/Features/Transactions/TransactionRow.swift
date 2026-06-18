import SwiftUI

enum TransactionListMetrics {
    /// Matches `CFHoverRow` horizontal padding so day totals line up with row amounts.
    static let rowContentInset: CGFloat = 12
    static let amountColumnMinWidth: CGFloat = 108
}

struct TransactionRow: View {
    let transaction: Transaction

    @EnvironmentObject private var privacy: PrivacyMode

    var body: some View {
        HStack(spacing: 14) {
            CFIconBadge(
                symbolName: rowSymbol,
                tint: rowTint,
                size: CFTheme.iconSize
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(rowTitle)
                        .font(CFTheme.body())
                        .foregroundStyle(CFTheme.textPrimary)
                    if isPlanned {
                        plannedBadge
                    }
                    if transaction.isTransfer {
                        transferBadge
                    }
                    if transaction.isInstallment, let plan = transaction.installmentPlan {
                        installmentBadge(plan: plan)
                    }
                    if transaction.isRecurring {
                        recurringBadge
                    }
                }

                HStack(spacing: 6) {
                    if let account = transaction.account {
                        Image(systemName: account.symbolName)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: account.colorHex))
                        Text(account.name)
                            .font(.caption)
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                    if let billingCaption = transaction.billingCycleCaption() {
                        if transaction.account != nil {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(CFTheme.textTertiary)
                        }
                        Text(billingCaption)
                            .font(.caption)
                            .foregroundStyle(CFTheme.textTertiary)
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
                .font(CFTheme.kpiValue())
                .foregroundStyle(amountColor)
                .frame(minWidth: TransactionListMetrics.amountColumnMinWidth, alignment: .trailing)
        }
        .opacity(isPlanned ? 0.7 : 1)
    }

    private var isPlanned: Bool {
        transaction.occurredOn > .now
    }

    private var rowTitle: String {
        if transaction.isTransfer {
            switch (transaction.account?.kind, transaction.kind) {
            case (.investment, .income), (.bank, .expense):
                return "Aporte"
            case (.investment, .expense), (.bank, .income):
                return "Resgate"
            default:
                return "Transferência"
            }
        }
        return transaction.category?.name ?? "Sem categoria"
    }

    private var plannedBadge: some View {
        Text("Previsto")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(CFTheme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(CFTheme.textTertiary.opacity(0.18))
            )
    }

    private var transferBadge: some View {
        Text("Transferência")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(CFTheme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(CFTheme.textTertiary.opacity(0.18))
            )
    }

    private func installmentBadge(plan: InstallmentPlan) -> some View {
        Text("\(transaction.installmentIndex)/\(plan.installmentCount)")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(CFTheme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(CFTheme.textTertiary.opacity(0.18))
            )
    }

    private var recurringBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "repeat")
                .font(.caption2.weight(.semibold))
            Text("Recorrente")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(CFTheme.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(CFTheme.textTertiary.opacity(0.18))
        )
    }

    private var rowSymbol: String {
        if transaction.isTransfer {
            return "chart.line.uptrend.xyaxis"
        }
        return transaction.category?.symbolName ?? "questionmark.circle"
    }

    private var rowTint: Color {
        transaction.kind == .expense ? CFTheme.expense : CFTheme.income
    }

    private var formattedAmount: String {
        let prefix = transaction.kind == .expense ? "−" : "+"
        return "\(prefix)\(transaction.amount.brl(masked: privacy.valuesHidden))"
    }

    private var amountColor: Color {
        CFTheme.textPrimary
    }
}
