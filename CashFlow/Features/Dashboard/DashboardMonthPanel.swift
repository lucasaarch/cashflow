import SwiftUI

struct DashboardMonthPanel: View {
    let summary: MonthSummary
    let history: SpendingHistoryContext
    let showsPace: Bool


    private var monthBalance: Decimal {
        summary.totalIncome - summary.totalExpense
    }

    private var hasPlannedRow: Bool {
        summary.hasPlanned
    }

    var body: some View {
        CFPanel {
            CFPanelSection(title: "Este mês", subtitle: "Realizado, ritmo e comparação com seu histórico") {
                HStack(spacing: 8) {
                    CFStatChip(label: "Entrou", amount: summary.totalIncome, tint: CFTheme.income, icon: "arrow.down.left")
                    CFStatChip(label: "Saiu", amount: summary.totalExpense, tint: CFTheme.expense, icon: "arrow.up.right")
                    CFStatChip(
                        label: "Saldo",
                        amount: monthBalance,
                        tint: monthBalance >= 0 ? CFTheme.income : CFTheme.danger,
                        icon: "equal.circle"
                    )
                }

                if hasPlannedRow {
                    HStack(spacing: 12) {
                        if summary.plannedIncome > 0 {
                            plannedLabel("Prev. entrada", amount: summary.plannedIncome, tint: CFTheme.income)
                        }
                        if summary.pendingReceivableIncome > 0 {
                            plannedLabel("A receber", amount: summary.pendingReceivableIncome, tint: CFTheme.accent)
                        }
                        if summary.plannedExpense > 0 {
                            plannedLabel("Prev. saída", amount: summary.plannedExpense, tint: CFTheme.expense)
                        }
                    }
                    .font(CFTheme.dashboardMeta())
                    .foregroundStyle(CFTheme.textTertiary)
                    .padding(.top, 2)
                }

                if summary.expectedIncome > 0 {
                    Text("Esperado no mês: \(summary.expectedIncome.brl)")
                        .font(CFTheme.dashboardMeta())
                        .foregroundStyle(CFTheme.textSecondary)
                        .padding(.top, 2)
                }

                if showsPace {
                    CFPanelDivider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Ritmo vs renda esperada")
                            .font(CFTheme.dashboardMeta().weight(.medium))
                            .foregroundStyle(CFTheme.textSecondary)
                        DashboardPaceInline(summary: summary)
                    }
                }

                if history.sampleCount >= 2 {
                    CFPanelDivider()
                    DashboardHistoryInline(history: history)
                }
            }
        }
    }

    private func plannedLabel(_ label: String, amount: Decimal, tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint.opacity(0.6)).frame(width: 5, height: 5)
            Text("\(label) \(amount.brl)")
        }
    }
}

private struct DashboardHistoryInline: View {
    let history: SpendingHistoryContext


    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text("Vs seu histórico")
                    .font(CFTheme.dashboardMeta().weight(.medium))
                    .foregroundStyle(CFTheme.textSecondary)
                Spacer(minLength: 8)
                Text("últimos \(history.sampleCount) meses")
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textTertiary)
            }

            HStack(spacing: 6) {
                Image(systemName: history.progressTrend.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(trendColor)
                Text(history.progressTrend.label)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(trendColor)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                CFStatChip(
                    label: "Gastou",
                    amount: history.currentExpense,
                    tint: CFTheme.expense,
                    icon: "arrow.up.right"
                )
                if let average = history.averageMonthlyExpense {
                    CFStatChip(
                        label: "Média mensal",
                        amount: average,
                        tint: CFTheme.textSecondary,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
                if let projected = history.projectedMonthExpense {
                    CFStatChip(
                        label: "Gasto projetado",
                        amount: projected,
                        tint: trendColor,
                        icon: "scope"
                    )
                }
            }

            if let typical = history.typicalExpenseAtCurrentProgress, history.dayProgress > 0.01 {
                CFProgressBar(
                    progress: min(history.progressVsTypicalRatio ?? 0, 1.5),
                    color: trendColor,
                    height: 5
                )

                Text("Até aqui no mês, você costuma gastar cerca de \(typical.brl). Hoje está em \(history.currentExpense.brl).")
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var trendColor: Color {
        switch history.progressTrend {
        case .belowUsual: return CFTheme.income
        case .onUsual: return CFTheme.accent
        case .aboveUsual: return CFTheme.warning
        case .insufficientData: return CFTheme.textSecondary
        }
    }
}

private struct DashboardPaceInline: View {
    let summary: MonthSummary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: summary.paceState.symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(CFTheme.paceColor(for: summary.paceState))
                    .scaleEffect(summary.paceState == .danger && !reduceMotion ? (pulse ? 1.08 : 1) : 1)
                Text(summary.paceState.label)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(CFTheme.paceColor(for: summary.paceState))
                Spacer()
                if summary.daysRemaining > 0 {
                    Text("\(summary.dailyBudgetRemaining.brl)/dia")
                        .font(CFTheme.dashboardAmount())
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }
            .onAppear { updatePulseDeferred() }
            .onChange(of: summary.paceState) { _, _ in updatePulseDeferred() }

            CFProgressBar(progress: summary.dayProgress, color: CFTheme.textTertiary.opacity(0.35), height: 5)
            CFProgressBar(
                progress: min(summary.spentRatio, 1.5),
                color: CFTheme.paceColor(for: summary.paceState),
                height: 5
            )
        }
    }

    private func updatePulseDeferred() {
        Task { @MainActor in
            updatePulse()
        }
    }

    private func updatePulse() {
        guard !reduceMotion, summary.paceState == .danger else {
            pulse = false
            return
        }
        pulse = false
        withAnimation(CFMotion.snappy.repeatForever(autoreverses: true)) { pulse = true }
    }
}
