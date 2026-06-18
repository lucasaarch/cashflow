import SwiftUI
import SwiftData

/// Compact combined panel for bills, receivables, goals and investments — hidden when all empty.
/// Filters bills/receivables to the selected reference month so the dashboard stays in sync
/// with the month navigator.
struct DashboardHighlightsPanel: View {
    @EnvironmentObject private var privacy: PrivacyMode

    let bills: [Bill]
    let receivables: [Receivable]
    let goals: [FinancialGoal]
    let transactions: [Transaction]
    let referenceDate: Date
    let investedThisMonth: Decimal
    let totalInvested: Decimal

    private var monthInterval: DateInterval? {
        Calendar.current.dateInterval(of: .month, for: referenceDate)
    }

    private var upcomingBills: [Bill] {
        guard let monthInterval else { return [] }
        return bills
            .filter { $0.isPending && monthInterval.contains($0.dueDate) }
            .sorted { lhs, rhs in
                if lhs.isOverdue() != rhs.isOverdue() { return lhs.isOverdue() }
                return lhs.dueDate < rhs.dueDate
            }
            .prefix(3)
            .map { $0 }
    }

    private var upcomingReceivables: [Receivable] {
        guard let monthInterval else { return [] }
        return receivables
            .filter { $0.isPending && monthInterval.contains($0.expectedDate) }
            .sorted { lhs, rhs in
                if lhs.isLate() != rhs.isLate() { return lhs.isLate() }
                return lhs.expectedDate < rhs.expectedDate
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
    private var showsReceivables: Bool { !upcomingReceivables.isEmpty }
    private var showsGoals: Bool { !activeGoals.isEmpty }
    private var showsInvestments: Bool { totalInvested > 0 || investedThisMonth != 0 }

    var shouldShow: Bool { showsBills || showsReceivables || showsGoals || showsInvestments }

    var body: some View {
        CFPanel {
            if showsBills {
                billsSection
            }
            if showsReceivables {
                if showsBills { CFPanelDivider() }
                receivablesSection
            }
            if showsGoals {
                if showsBills || showsReceivables { CFPanelDivider() }
                goalsSection
            }
            if showsInvestments {
                if showsBills || showsReceivables || showsGoals { CFPanelDivider() }
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
                        Spacer(minLength: 8)
                        Text(bill.amount.brl(masked: privacy.valuesHidden))
                            .font(CFTheme.dashboardAmount())
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text(compactDay(bill.dueDate))
                            .font(CFTheme.dashboardMeta())
                            .foregroundStyle(bill.isOverdue() ? CFTheme.danger : CFTheme.textTertiary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }

    private var receivablesSection: some View {
        CFPanelSection(title: "A receber", subtitle: receivablesSubtitle) {
            VStack(spacing: 6) {
                ForEach(upcomingReceivables) { receivable in
                    HStack(spacing: 8) {
                        Image(systemName: "tray.and.arrow.down")
                            .font(.caption)
                            .foregroundStyle(receivable.isLate() ? CFTheme.warning : CFTheme.accent)
                            .frame(width: 16)
                        Text(receivable.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(receivable.amount.brl(masked: privacy.valuesHidden))
                            .font(CFTheme.dashboardAmount())
                            .foregroundStyle(CFTheme.income)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        Text(compactDay(receivable.expectedDate))
                            .font(CFTheme.dashboardMeta())
                            .foregroundStyle(receivable.isLate() ? CFTheme.warning : CFTheme.textTertiary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
        }
    }

    /// Short single-line day phrase suited to a tight HStack: "hoje", "ontem",
    /// "+3d", "-5d" (within ±7 days) or "17/jun" otherwise.
    private func compactDay(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: date)
        guard let diff = calendar.dateComponents([.day], from: today, to: target).day else {
            return absoluteCompactDay(date)
        }
        switch diff {
        case 0: return "hoje"
        case 1: return "amanhã"
        case -1: return "ontem"
        case 2...7: return "+\(diff)d"
        case (-7)...(-2): return "\(diff)d"
        default: return absoluteCompactDay(date)
        }
    }

    private func absoluteCompactDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Money.locale
        formatter.dateFormat = "d/MMM"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }

    private var receivablesSubtitle: String {
        let late = upcomingReceivables.filter { $0.isLate() }.count
        if late > 0 { return "\(late) atrasada\(late == 1 ? "" : "s")" }
        return "Recebimentos do mês"
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
        let overdue = upcomingBills.filter { $0.isOverdue() }.count
        if overdue > 0 { return "\(overdue) vencida\(overdue == 1 ? "" : "s")" }
        return "Vencimentos do mês"
    }
}
