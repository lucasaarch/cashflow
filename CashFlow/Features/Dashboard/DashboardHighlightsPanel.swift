import SwiftUI
import SwiftData

/// Compact combined panel for bills, goals and investments — hidden when all empty.
struct DashboardHighlightsPanel: View {
    let bills: [Bill]
    let goals: [FinancialGoal]
    let transactions: [Transaction]
    let investedThisMonth: Decimal
    let totalInvested: Decimal

    private var upcomingBills: [Bill] {
        bills
            .filter { $0.isPending }
            .sorted { lhs, rhs in
                if lhs.isOverdue() != rhs.isOverdue() { return lhs.isOverdue() }
                return lhs.dueDate < rhs.dueDate
            }
            .prefix(3)
            .map { $0 }
    }

    private var activeGoals: [(FinancialGoal, GoalProgressSnapshot)] {
        goals
            .filter { !$0.isCompleted }
            .map { ($0, GoalProgressCalculator.snapshot(for: $0, transactions: transactions)) }
            .sorted { $0.1.progress > $1.1.progress }
            .prefix(2)
            .map { $0 }
    }

    private var showsBills: Bool { !upcomingBills.isEmpty }
    private var showsGoals: Bool { !activeGoals.isEmpty }
    private var showsInvestments: Bool { totalInvested > 0 || investedThisMonth != 0 }

    var shouldShow: Bool { showsBills || showsGoals || showsInvestments }

    var body: some View {
        CFPanel {
            if showsBills {
                billsSection
            }
            if showsGoals {
                if showsBills { CFPanelDivider() }
                goalsSection
            }
            if showsInvestments {
                if showsBills || showsGoals { CFPanelDivider() }
                investmentsSection
            }
        }
    }

    private var billsSection: some View {
        CFPanelSection(title: "Contas a pagar", subtitle: billsSubtitle) {
            VStack(spacing: 6) {
                ForEach(upcomingBills) { bill in
                    HStack(spacing: 8) {
                        Image(systemName: bill.isCardStatement ? "creditcard.fill" : "doc.text")
                            .font(.caption)
                            .foregroundStyle(bill.isOverdue() ? CFTheme.danger : CFTheme.warning)
                            .frame(width: 16)
                        Text(bill.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text(bill.amount.brl)
                            .font(.caption.monospacedDigit().weight(.medium))
                        Text(bill.dueDate.formatted(.dateTime.day().month(.abbreviated).locale(Money.locale)))
                            .font(.caption2)
                            .foregroundStyle(bill.isOverdue() ? CFTheme.danger : CFTheme.textTertiary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var goalsSection: some View {
        CFPanelSection(title: "Metas", subtitle: "\(goals.filter { !$0.isCompleted }.count) em andamento") {
            VStack(spacing: 10) {
                ForEach(activeGoals, id: \.0.id) { goal, snapshot in
                    GoalProgressCard(snapshot: snapshot, goal: goal, compact: true)
                }
            }
        }
    }

    private var investmentsSection: some View {
        CFPanelSection(title: "Investimentos") {
            HStack(spacing: 8) {
                if investedThisMonth != 0 {
                    CFStatChip(
                        label: "No mês",
                        amount: investedThisMonth,
                        tint: investedThisMonth >= 0 ? CFTheme.accent : CFTheme.warning,
                        icon: "arrow.up.circle"
                    )
                }
                if totalInvested > 0 {
                    CFStatChip(
                        label: "Total",
                        amount: totalInvested,
                        tint: CFTheme.accent,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                }
            }
        }
    }

    private var billsSubtitle: String {
        let overdue = bills.filter { $0.isPending && $0.isOverdue() }.count
        if overdue > 0 { return "\(overdue) vencida\(overdue == 1 ? "" : "s")" }
        return "Próximos vencimentos"
    }
}
