import SwiftUI

struct DashboardWeekCommitmentsPanel: View {
    let bills: [Bill]
    let receivables: [Receivable]
    let recurringExpenses: [RecurringExpense]
    let recurringIncomes: [RecurringIncome]
    let referenceDate: Date


    private var weekInterval: DateInterval? {
        Calendar.current.dateInterval(of: .weekOfYear, for: referenceDate)
    }

    private var weekBills: [Bill] {
        guard let interval = weekInterval else { return [] }
        return bills.filter { $0.isPending && interval.contains($0.dueDate) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var weekReceivables: [Receivable] {
        guard let interval = weekInterval else { return [] }
        return receivables.filter { $0.isPending && interval.contains($0.expectedDate) }
            .sorted { $0.expectedDate < $1.expectedDate }
    }

    private var billsTotal: Decimal {
        weekBills.reduce(0) { $0 + $1.amount }
    }

    private var receivablesTotal: Decimal {
        weekReceivables.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        if weekBills.isEmpty && weekReceivables.isEmpty {
            EmptyView()
        } else {
            CFPanel {
                CFPanelSection(title: "Compromissos da semana", subtitle: "Contas e recebimentos previstos") {
                    HStack(spacing: 8) {
                        CFStatChip(label: "A pagar", amount: billsTotal, tint: CFTheme.expense, icon: "calendar.badge.clock")
                        CFStatChip(label: "A receber", amount: receivablesTotal, tint: CFTheme.income, icon: "tray.and.arrow.down.fill")
                    }

                    if !weekBills.isEmpty {
                        commitmentList(title: "Contas", items: weekBills.map {
                            ($0.name, $0.dueDate, $0.amount, CFTheme.expense)
                        })
                    }

                    if !weekReceivables.isEmpty {
                        commitmentList(title: "Recebimentos", items: weekReceivables.map {
                            ($0.name, $0.expectedDate, $0.amount, CFTheme.income)
                        })
                    }
                }
            }
        }
    }

    private func commitmentList(
        title: String,
        items: [(String, Date, Decimal, Color)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.top, 4)

            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.0)
                            .font(CFTheme.body())
                            .foregroundStyle(CFTheme.textPrimary)
                        Text(item.1.formatted(date: .abbreviated, time: .omitted))
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                    Spacer()
                    Text(item.2.brl)
                        .font(CFTheme.body().weight(.semibold))
                        .foregroundStyle(item.3)
                }
            }
        }
    }
}
