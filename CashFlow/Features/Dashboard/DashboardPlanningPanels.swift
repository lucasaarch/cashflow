import SwiftUI
import SwiftData

struct DashboardProjectionPanel: View {
    let summary: MonthSummary
    let overview: FinancialOverview
    let bills: [Bill]
    let receivables: [Receivable]
    let referenceDate: Date


    private var pendingBills: [Bill] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: referenceDate) else { return [] }
        return bills.filter { $0.isPending && $0.dueDate >= .now && interval.contains($0.dueDate) }
    }

    private var pendingReceivables: [Receivable] {
        guard let interval = Calendar.current.dateInterval(of: .month, for: referenceDate) else { return [] }
        return receivables.filter { $0.isPending && $0.expectedDate >= .now && interval.contains($0.expectedDate) }
    }

    private var billsTotal: Decimal {
        pendingBills.reduce(0) { $0 + $1.amount }
    }

    private var receivablesTotal: Decimal {
        pendingReceivables.reduce(0) { $0 + $1.amount }
    }

    private var projectedAvailable: Decimal {
        overview.liquidBalance + receivablesTotal - billsTotal
    }

    var body: some View {
        CFPanel {
            CFPanelSection(title: "Caixa projetado", subtitle: "Disponível hoje + a receber − contas a pagar") {
                HStack(spacing: 8) {
                    CFStatChip(label: "Disponível", amount: overview.liquidBalance, tint: CFTheme.accent, icon: "building.columns.fill")
                    CFStatChip(label: "A receber", amount: receivablesTotal, tint: CFTheme.income, icon: "tray.and.arrow.down.fill")
                    CFStatChip(label: "A pagar", amount: billsTotal, tint: CFTheme.expense, icon: "calendar.badge.clock")
                }

                CFPanelDivider()

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Saldo projetado")
                            .font(CFTheme.dashboardLabel())
                            .foregroundStyle(CFTheme.textSecondary)
                        Text(projectedAvailable.brl)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(projectedAvailable >= 0 ? CFTheme.income : CFTheme.danger)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    Spacer(minLength: 8)
                    Label(projectedAvailable >= 0 ? "Respira" : "Atenção", systemImage: projectedAvailable >= 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(projectedAvailable >= 0 ? CFTheme.income : CFTheme.danger)
                }

                if summary.projectedBalance != projectedAvailable {
                    Text("Fluxo do mês (entrou − saiu − previsto): \(summary.projectedBalance.brl)")
                        .font(CFTheme.dashboardMeta())
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }
        }
    }
}

struct DashboardInboxPanel: View {
    let summary: MonthSummary
    let overview: FinancialOverview
    let bills: [Bill]
    let receivables: [Receivable]
    let wishlistItems: [WishlistItem]
    let referenceDate: Date

    private var alerts: [DashboardAlert] {
        var items: [DashboardAlert] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today) ?? today

        let urgentBills = bills
            .filter { $0.isPending && $0.dueDate <= nextWeek }
            .sorted { $0.dueDate < $1.dueDate }
            .prefix(3)
        for bill in urgentBills {
            items.append(DashboardAlert(
                icon: bill.isOverdue() ? "exclamationmark.triangle.fill" : "calendar.badge.clock",
                title: bill.isOverdue() ? "Conta vencida" : "Conta próxima",
                detail: "\(bill.name) · \(compactDay(bill.dueDate))",
                tint: bill.isOverdue() ? CFTheme.danger : CFTheme.warning
            ))
        }

        let lateReceivables = receivables
            .filter { $0.isPending && $0.expectedDate <= today }
            .sorted { $0.expectedDate < $1.expectedDate }
            .prefix(2)
        for receivable in lateReceivables {
            items.append(DashboardAlert(
                icon: "tray.and.arrow.down.fill",
                title: receivable.isLate() ? "Recebível atrasado" : "Recebível para hoje",
                detail: receivable.name,
                tint: CFTheme.accent
            ))
        }

        if summary.paceState == .danger || summary.paceState == .warning {
            items.append(DashboardAlert(
                icon: summary.paceState.symbol,
                title: summary.paceState.label,
                detail: "Revise gastos antes de assumir novas saídas.",
                tint: CFTheme.paceColor(for: summary.paceState)
            ))
        }

        if overview.debtBalance > overview.liquidBalance {
            items.append(DashboardAlert(
                icon: "creditcard.fill",
                title: "Cartões acima do caixa",
                detail: "Priorize entradas e evite compras parceladas.",
                tint: CFTheme.debt
            ))
        }

        if summary.projectedBalance < 0, let item = wishlistItems.sorted(by: { $0.priority.sortRank < $1.priority.sortRank }).first {
            items.append(DashboardAlert(
                icon: "cart.fill",
                title: "Desejo para segurar",
                detail: item.name,
                tint: CFTheme.warning
            ))
        }

        return Array(items.prefix(5))
    }

    var body: some View {
        if !alerts.isEmpty {
            CFPanel {
                CFPanelSection(title: "Hoje", subtitle: "O que pede atenção") {
                    VStack(spacing: 8) {
                        ForEach(alerts) { alert in
                            HStack(spacing: 10) {
                                Image(systemName: alert.icon)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(alert.tint)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(alert.title)
                                        .font(.callout.weight(.medium))
                                        .foregroundStyle(CFTheme.textPrimary)
                                    Text(alert.detail)
                                        .font(CFTheme.dashboardMeta())
                                        .foregroundStyle(CFTheme.textSecondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private func compactDay(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        switch days {
        case 0: return "hoje"
        case 1: return "amanhã"
        case ..<0: return "vencida"
        default: return "+\(days)d"
        }
    }
}

struct DashboardRecoveryPlanPanel: View {
    let summary: MonthSummary
    let overview: FinancialOverview
    let bills: [Bill]
    let receivables: [Receivable]
    let wishlistItems: [WishlistItem]

    private var needsPlan: Bool {
        summary.balance < 0 || summary.projectedBalance < 0 || summary.paceState == .danger || overview.debtBalance > overview.liquidBalance
    }

    private var actions: [RecoveryAction] {
        var items: [RecoveryAction] = []

        let overdueBills = bills.filter { $0.isOverdue() }.sorted { $0.dueDate < $1.dueDate }
        if let bill = overdueBills.first {
            items.append(RecoveryAction(
                icon: "calendar.badge.exclamationmark",
                title: "Resolver a conta mais urgente",
                detail: "Comece por \(bill.name) antes de assumir novas saídas.",
                tint: CFTheme.danger
            ))
        }

        let lateReceivableTotal = receivables.filter { $0.isLate() }.reduce(Decimal(0)) { $0 + $1.amount }
        if lateReceivableTotal > 0 {
            items.append(RecoveryAction(
                icon: "phone.arrow.up.right",
                title: "Cobrar recebíveis atrasados",
                detail: "Há \(lateReceivableTotal.brl) que pode aliviar o caixa.",
                tint: CFTheme.accent
            ))
        }

        if summary.dailyBudgetRemaining > 0 {
            items.append(RecoveryAction(
                icon: "target",
                title: "Teto diário até virar o mês",
                detail: "Mantenha gastos variáveis perto de \(summary.dailyBudgetRemaining.brl)/dia.",
                tint: CFTheme.income
            ))
        } else {
            items.append(RecoveryAction(
                icon: "scissors",
                title: "Cortar gastos variáveis agora",
                detail: "O caixa projetado não comporta novas despesas discricionárias.",
                tint: CFTheme.warning
            ))
        }

        if let wishlist = wishlistItems.sorted(by: { $0.estimatedAmount > $1.estimatedAmount }).first {
            items.append(RecoveryAction(
                icon: "pause.circle.fill",
                title: "Congelar desejo temporariamente",
                detail: "Segure \(wishlist.name) até o saldo realizado voltar ao positivo.",
                tint: CFTheme.warning
            ))
        }

        if overview.debtBalance > 0 {
            items.append(RecoveryAction(
                icon: "creditcard.trianglebadge.exclamationmark",
                title: "Evitar ampliar cartão",
                detail: "Cartões somam \(overview.debtBalance.brl); preserve caixa para a fatura.",
                tint: CFTheme.debt
            ))
        }

        return Array(items.prefix(4))
    }

    var body: some View {
        if needsPlan {
            CFPanel {
                CFPanelSection(title: "Plano de recuperação", subtitle: "Ações automáticas com seus dados") {
                    VStack(spacing: 10) {
                        ForEach(actions) { action in
                            HStack(alignment: .top, spacing: 10) {
                                CFIconBadge(symbolName: action.icon, tint: action.tint, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(action.title)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(CFTheme.textPrimary)
                                    Text(action.detail)
                                        .font(CFTheme.dashboardMeta())
                                        .foregroundStyle(CFTheme.textSecondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}

private struct DashboardAlert: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}

private struct RecoveryAction: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let tint: Color
}
