import SwiftUI

struct AccountBreakdownCard: View {
    let aggregates: [MonthSummary.AccountAggregate]

    var body: some View {
        DashboardCard(title: "Por conta", subtitle: "Distribuição dos gastos por forma de pagamento") {
            if aggregates.isEmpty {
                HStack {
                    Image(systemName: "wallet.pass")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                    Text("Nenhum gasto registrado.")
                        .foregroundStyle(.secondary)
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
        let isDebt = item.account.kind == .externalDebt
        let tint = Color(hex: item.account.colorHex)
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.16))
                    .frame(width: 32, height: 32)
                Image(systemName: item.account.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(item.account.name)
                    .font(.callout)
                Text(isDebt ? "A pagar para ela" : "\(item.count) \(item.count == 1 ? "lançamento" : "lançamentos")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(item.total.brl)
                .font(.callout.monospacedDigit().weight(.medium))
                .foregroundStyle(isDebt ? .pink : .primary)
        }
        .padding(.vertical, 4)
    }
}
