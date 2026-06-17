import SwiftUI

struct DashboardMonthPanel: View {
    let summary: MonthSummary
    let showsPace: Bool
    @Binding var editingIncome: Bool
    @Binding var monthlyIncomeCents: Int

    private var monthBalance: Decimal {
        summary.totalIncome - summary.totalExpense
    }

    var body: some View {
        CFPanel {
            CFPanelSection(title: "Fluxo do mês", subtitle: "Realizado no período selecionado") {
                CFPillButton(
                    title: monthlyIncomeCents == 0 ? "Orçamento" : "Editar orçamento",
                    icon: monthlyIncomeCents == 0 ? "plus.circle" : "pencil",
                    style: .ghost
                ) {
                    editingIncome.toggle()
                }
            } content: {
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

                if summary.hasPlanned {
                    HStack(spacing: 12) {
                        if summary.plannedIncome > 0 {
                            plannedLabel("Prev. entrada", amount: summary.plannedIncome, tint: CFTheme.income)
                        }
                        if summary.plannedExpense > 0 {
                            plannedLabel("Prev. saída", amount: summary.plannedExpense, tint: CFTheme.expense)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(CFTheme.textTertiary)
                    .padding(.top, 2)
                }

                if showsPace {
                    CFPanelDivider()
                    DashboardPaceInline(summary: summary)
                }
            }
        }
        .cfAdaptivePicker(isPresented: $editingIncome, arrowEdge: .top, sheetTitle: "Renda mensal") {
            MonthlyIncomeEditor(cents: $monthlyIncomeCents)
                .frame(width: 300)
        }
    }

    private func plannedLabel(_ label: String, amount: Decimal, tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint.opacity(0.6)).frame(width: 5, height: 5)
            Text("\(label) \(amount.brl)")
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CFTheme.paceColor(for: summary.paceState))
                    .scaleEffect(summary.paceState == .danger && !reduceMotion ? (pulse ? 1.08 : 1) : 1)
                Text(summary.paceState.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(CFTheme.paceColor(for: summary.paceState))
                Spacer()
                if summary.daysRemaining > 0 {
                    Text("\(summary.dailyBudgetRemaining.brl)/dia")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }
            .onAppear { updatePulse() }
            .onChange(of: summary.paceState) { _, _ in updatePulse() }

            CFProgressBar(progress: summary.dayProgress, color: CFTheme.textTertiary.opacity(0.35), height: 5)
            CFProgressBar(
                progress: min(summary.spentRatio, 1.5),
                color: CFTheme.paceColor(for: summary.paceState),
                height: 5
            )
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
