import SwiftUI

struct DashboardHeroPanel: View {
    let overview: FinancialOverview

    private var statChips: [(label: String, amount: Decimal, tint: Color, icon: String)] {
        var chips: [(String, Decimal, Color, String)] = [
            ("Disponível", overview.liquidBalance, CFTheme.accent, "building.columns.fill"),
            ("Investido", overview.totalInvestedBalance, CFTheme.accent, "chart.line.uptrend.xyaxis")
        ]
        if overview.debtBalance > 0 {
            chips.append(("Cartões", overview.debtBalance, CFTheme.debt, "creditcard.fill"))
        }
        if overview.pendingBillsTotal > 0 {
            chips.append((
                "A pagar",
                overview.pendingBillsTotal,
                overview.overdueBillsCount > 0 ? CFTheme.danger : CFTheme.warning,
                "calendar.badge.clock"
            ))
        }
        return chips
    }

    var body: some View {
        CFPanel(padding: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Patrimônio líquido")
                    .font(CFTheme.dashboardLabel())
                    .foregroundStyle(CFTheme.textSecondary)
                    .textCase(.uppercase)
                CFAnimatedAmount(
                    amount: overview.netWorth,
                    font: CFTheme.heroAmount(),
                    color: overview.netWorth >= 0 ? CFTheme.textPrimary : CFTheme.danger
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !statChips.isEmpty {
                CFPanelDivider()
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    ForEach(Array(statChips.enumerated()), id: \.offset) { _, chip in
                        CFStatChip(
                            label: chip.label,
                            amount: chip.amount,
                            tint: chip.tint,
                            icon: chip.icon
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
