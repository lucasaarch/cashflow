import SwiftUI

struct DashboardInstallmentsPanel: View {
    let transactions: [Transaction]
    let referenceDate: Date


    private var commitments: [InstallmentCommitmentCalculator.MonthCommitment] {
        InstallmentCommitmentCalculator.upcomingCommitments(
            transactions: transactions,
            from: referenceDate,
            monthCount: 4
        )
    }

    private var next30DaysTotal: Decimal {
        InstallmentCommitmentCalculator.totalUpcoming(
            transactions: transactions,
            from: referenceDate,
            withinDays: 30
        )
    }

    var body: some View {
        if commitments.isEmpty {
            EmptyView()
        } else {
            CFPanel {
                CFPanelSection(
                    title: "Parcelas futuras",
                    subtitle: "Comprometimento de cartão nos próximos meses"
                ) {
                    if next30DaysTotal > 0 {
                        Text("Próximos 30 dias: \(next30DaysTotal.brl)")
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                    }

                    ForEach(commitments) { commitment in
                        HStack {
                            Text(commitment.monthStart.formatted(.dateTime.month(.wide).year()))
                                .font(CFTheme.body())
                                .foregroundStyle(CFTheme.textPrimary)
                            Spacer()
                            Text("\(commitment.count) parcela(s)")
                                .font(CFTheme.caption())
                                .foregroundStyle(CFTheme.textSecondary)
                            Text(commitment.total.brl)
                                .font(CFTheme.body().weight(.semibold))
                                .foregroundStyle(CFTheme.expense)
                        }
                    }
                }
            }
        }
    }
}

struct DashboardCategoryBudgetsPanel: View {
    let summary: MonthSummary


    var body: some View {
        if summary.categoryBudgetStatuses.isEmpty {
            EmptyView()
        } else {
            CFPanel {
                CFPanelSection(
                    title: "Limites por categoria",
                    subtitle: "Quanto já gastou vs. o teto que você definiu em Categorias"
                ) {
                    ForEach(summary.categoryBudgetStatuses.prefix(6)) { status in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(status.category.name)
                                    .font(CFTheme.body())
                                    .foregroundStyle(CFTheme.textPrimary)
                                Spacer()
                                Text("\(status.spent.brl) / \(status.limit.brl)")
                                    .font(CFTheme.caption())
                                    .foregroundStyle(status.ratio > 1 ? CFTheme.danger : CFTheme.textSecondary)
                            }
                            CFProgressBar(progress: min(status.ratio, 1))
                        }
                    }
                }
            }
        }
    }
}
