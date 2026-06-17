import SwiftUI
import SwiftData

struct MonthDashboardView: View {
    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @AppStorage(UserDefaultsKeys.monthlyIncomeCents) private var monthlyIncomeCents: Int = 0
    @State private var referenceDate: Date = .now
    @State private var editingIncome = false

    private var summary: MonthSummary {
        MonthSummary(
            referenceDate: referenceDate,
            monthlyIncomeBudget: Decimal(monthlyIncomeCents) / 100,
            transactions: transactions
        )
    }

    private var liquidBalance: Decimal {
        accounts
            .filter { $0.kind.isLiquid }
            .reduce(Decimal(0)) { $0 + $1.currentBalance(considering: transactions) }
    }

    private var debtBalance: Decimal {
        accounts
            .filter { !$0.kind.isLiquid }
            .reduce(Decimal(0)) { $0 + abs($1.currentBalance(considering: transactions)) }
    }

    var body: some View {
        Group {
            if accounts.isEmpty {
                emptyState
            } else {
                dashboardScroll
            }
        }
        .navigationTitle("Visão geral")
        .toolbar {
            if !accounts.isEmpty {
                ToolbarItem(placement: .navigation) {
                    monthNavigator
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Comece criando uma conta", systemImage: "wallet.pass")
        } description: {
            Text("Cadastre suas contas com o saldo atual de cada uma. Depois é só registrar entradas e saídas pra ver onde o dinheiro está indo.")
        }
    }

    private var dashboardScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeroKPIsCard(
                    summary: summary,
                    liquidBalance: liquidBalance,
                    debtBalance: debtBalance,
                    editingIncome: $editingIncome,
                    monthlyIncomeCents: $monthlyIncomeCents
                )
                if monthlyIncomeCents > 0 {
                    PaceCard(summary: summary)
                }
                CategoryBreakdownCard(aggregates: summary.expensesByCategory,
                                      totalExpense: summary.totalExpense)
                AccountBreakdownCard(aggregates: summary.expensesByAccount)
            }
            .padding(20)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.windowBackgroundColor).opacity(0.4).ignoresSafeArea())
    }

    private var monthNavigator: some View {
        HStack(spacing: 6) {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .help("Mês anterior")

            Text(monthLabel)
                .font(.callout.weight(.medium))
                .frame(minWidth: 130)
                .multilineTextAlignment(.center)

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isCurrentMonth)
            .help("Mês seguinte")
        }
    }

    private var monthLabel: String {
        referenceDate.formatted(.dateTime.month(.wide).year().locale(Money.locale)).capitalized
    }

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(referenceDate, equalTo: .now, toGranularity: .month)
    }

    private func shiftMonth(by amount: Int) {
        if let new = Calendar.current.date(byAdding: .month, value: amount, to: referenceDate) {
            referenceDate = new
        }
    }
}

// MARK: - Hero KPIs

private struct HeroKPIsCard: View {
    let summary: MonthSummary
    let liquidBalance: Decimal
    let debtBalance: Decimal
    @Binding var editingIncome: Bool
    @Binding var monthlyIncomeCents: Int

    var body: some View {
        DashboardCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Saldo atual")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        editingIncome.toggle()
                    } label: {
                        Label(monthlyIncomeCents == 0 ? "Definir orçamento" : "Editar orçamento",
                              systemImage: monthlyIncomeCents == 0 ? "plus.circle" : "pencil")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Orçamento mensal")
                }

                Text(liquidBalance.brl)
                    .font(.system(size: 40, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(liquidBalance >= 0 ? Color.primary : Color.red)

                HStack(spacing: 14) {
                    kpiTile(label: "Entrou no mês",
                            value: summary.totalIncome,
                            icon: "arrow.down.left",
                            tint: .green)
                    Divider().frame(height: 36)
                    kpiTile(label: "Saiu no mês",
                            value: summary.totalExpense,
                            icon: "arrow.up.right",
                            tint: .red)
                    if debtBalance > 0 {
                        Divider().frame(height: 36)
                        kpiTile(label: "Devo pra ela",
                                value: debtBalance,
                                icon: "heart.fill",
                                tint: .pink)
                    }
                }
            }
        }
        .popover(isPresented: $editingIncome) {
            MonthlyIncomeEditor(cents: $monthlyIncomeCents)
                .frame(width: 300)
        }
    }

    private func kpiTile(label: String, value: Decimal, icon: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(tint.opacity(0.16)).frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value.brl)
                    .font(.callout.monospacedDigit().weight(.medium))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MonthlyIncomeEditor: View {
    @Binding var cents: Int
    @State private var amount: Decimal = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Orçamento mensal")
                .font(.headline)
            Text("Quanto você espera ter por mês. Usado pra calcular ritmo de gastos.")
                .font(.caption)
                .foregroundStyle(.secondary)
            CurrencyField(amount: $amount, placeholder: "R$ 0,00")
                .font(.title3)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
        .onAppear { amount = Decimal(cents) / 100 }
        .onChange(of: amount) { _, newValue in
            cents = NSDecimalNumber(decimal: newValue * 100).intValue
        }
    }
}

// MARK: - Pace card

private struct PaceCard: View {
    let summary: MonthSummary

    var body: some View {
        DashboardCard(title: "Ritmo do mês", subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: summary.paceState.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(paceColor)
                    Text(summary.paceState.label)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(paceColor)
                }

                doubleBar
                legend
            }
        }
    }

    private var doubleBar: some View {
        GeometryReader { geo in
            VStack(spacing: 6) {
                bar(progress: summary.dayProgress, color: .secondary.opacity(0.45), width: geo.size.width)
                bar(progress: min(summary.spentRatio, 1.5), color: paceColor, width: geo.size.width)
            }
        }
        .frame(height: 22)
    }

    private func bar(progress: Double, color: Color, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.12))
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: max(4, width * min(progress, 1)))
        }
        .frame(height: 8)
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(swatch: .secondary.opacity(0.45), label: "Mês passou", value: "\(Int(summary.dayProgress * 100))%")
            legendItem(swatch: paceColor, label: "Você gastou", value: "\(Int(summary.spentRatio * 100))%")
            Spacer()
            if summary.daysRemaining > 0 {
                Text("\(summary.dailyBudgetRemaining.brl) por dia até o fim")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    private func legendItem(swatch: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(swatch).frame(width: 10, height: 10)
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }

    private var subtitle: String {
        let remaining = summary.daysRemaining
        if remaining == 0 { return "Mês fechado" }
        return "Faltam \(remaining) \(remaining == 1 ? "dia" : "dias")"
    }

    private var paceColor: Color {
        switch summary.paceState {
        case .underspending: return .blue
        case .onTrack: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }
}
