import SwiftUI

struct AccountBreakdownCard: View {
    let aggregates: [MonthSummary.AccountAggregate]

    var body: some View {
        CFGlassCard(title: "Por conta", subtitle: "Distribuição dos gastos por forma de pagamento") {
            if aggregates.isEmpty {
                HStack {
                    Image(systemName: "wallet.pass")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(CFTheme.textSecondary)
                    Text("Nenhum gasto registrado.")
                        .foregroundStyle(CFTheme.textSecondary)
                    Spacer()
                }
                .font(.callout)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 12) {
                    ForEach(aggregates) { item in
                        row(item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: MonthSummary.AccountAggregate) -> some View {
        let isCard = item.account.kind == .creditCard
        let tint = Color(hex: item.account.colorHex)
        HStack(spacing: 12) {
            CFIconBadge(symbolName: item.account.symbolName, tint: tint, size: 32, cornerRadius: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.account.name)
                    .font(.callout)
                    .foregroundStyle(CFTheme.textPrimary)
                Text(captionLabel(isCard: isCard, count: item.count))
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
            }

            Spacer()

            CFAnimatedAmount(
                amount: item.total,
                font: .callout.monospacedDigit().weight(.medium),
                color: isCard ? CFTheme.debt : CFTheme.textPrimary
            )
        }
        .padding(.vertical, 4)
    }

    private func captionLabel(isCard: Bool, count: Int) -> String {
        let suffix = "\(count) \(count == 1 ? "lançamento" : "lançamentos")"
        return isCard ? "Cartão · \(suffix)" : suffix
    }
}
