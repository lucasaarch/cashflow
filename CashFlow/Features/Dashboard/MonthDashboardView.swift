import SwiftUI
import SwiftData

struct MonthDashboardView: View {
    @EnvironmentObject private var aiService: AIService

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @AppStorage(UserDefaultsKeys.monthlyIncomeCents) private var monthlyIncomeCents: Int = 0
    @State private var referenceDate: Date = .now
    @State private var editingIncome = false
    @State private var insightText: String?
    @State private var insightLoading = false
    @State private var insightError: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .cfPageBackground()
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "wallet.pass",
            title: "Comece criando uma conta",
            message: "Cadastre suas contas com o saldo atual de cada uma. Depois e so registrar entradas e saidas pra ver onde o dinheiro esta indo."
        )
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
                .cfStaggerAppear(index: 0)
                .id(referenceDate)

                if aiService.configuration.isReady {
                    insightCard
                        .cfStaggerAppear(index: 1)
                }

                if monthlyIncomeCents > 0 {
                    ViewThatFits {
                        HStack(alignment: .top, spacing: 16) {
                            PaceCard(summary: summary)
                                .frame(maxWidth: .infinity)
                            CategoryBreakdownCard(
                                aggregates: summary.expensesByCategory,
                                totalExpense: summary.totalExpense
                            )
                            .frame(maxWidth: .infinity)
                        }
                        VStack(spacing: 16) {
                            PaceCard(summary: summary)
                            CategoryBreakdownCard(
                                aggregates: summary.expensesByCategory,
                                totalExpense: summary.totalExpense
                            )
                        }
                    }
                    .cfStaggerAppear(index: 1)
                } else {
                    CategoryBreakdownCard(
                        aggregates: summary.expensesByCategory,
                        totalExpense: summary.totalExpense
                    )
                    .cfStaggerAppear(index: 1)
                }

                AccountBreakdownCard(aggregates: summary.expensesByAccount)
                    .cfStaggerAppear(index: 2)
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity
            ))
            .animation(reduceMotion ? nil : CFMotion.gentle, value: referenceDate)
        }
        .cfPageBackground()
        .onAppear(perform: loadCachedInsight)
        .onChange(of: referenceDate) { _, _ in loadCachedInsight() }
    }

    private var insightCard: some View {
        CFGlassCard(title: "Resumo inteligente") {
            VStack(alignment: .leading, spacing: 10) {
                if let insightText {
                    Text(insightText)
                        .font(CFTheme.body())
                        .foregroundStyle(CFTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Spacer()
                        CFPillButton(title: "Atualizar", style: .ghost) {
                            Task { await generateInsight(force: true) }
                        }
                    }
                } else if insightLoading {
                    ProgressView("Gerando resumo…")
                        .controlSize(.small)
                } else {
                    CFPillButton(title: "Gerar resumo", style: .primary) {
                        Task { await generateInsight(force: false) }
                    }
                }
                if let insightError {
                    Text(insightError)
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.expense)
                }
            }
        }
    }

    private var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: referenceDate)
    }

    private func loadCachedInsight() {
        insightText = AIInsightsService.cachedInsight(monthKey: monthKey)
        insightError = nil
    }

    private func generateInsight(force: Bool) async {
        if !force, insightText != nil { return }
        insightLoading = true
        insightError = nil
        defer { insightLoading = false }

        let calendar = Calendar.current
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        let previousSummary = MonthSummary(
            referenceDate: previousMonth,
            monthlyIncomeBudget: Decimal(monthlyIncomeCents) / 100,
            transactions: transactions
        )

        do {
            let text = try await AIInsightsService.generateInsight(
                summary: summary,
                transactions: summary.monthlyTransactions,
                previousMonthExpense: previousSummary.totalExpense,
                aiService: aiService
            )
            insightText = text
            AIInsightsService.cacheInsight(text, monthKey: monthKey)
        } catch {
            insightError = error.localizedDescription
        }
    }

    private var monthNavigator: some View {
        HStack(spacing: 6) {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Mês anterior")

            Text(monthLabel)
                .font(.callout.weight(.semibold))
                .foregroundStyle(CFTheme.textPrimary)
                .frame(minWidth: 130)
                .multilineTextAlignment(.center)
                .contentTransition(reduceMotion ? .identity : .numericText())

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(isCurrentMonth)
            .help("Mês seguinte")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(CFTheme.textTertiary.opacity(0.1)))
        .animation(reduceMotion ? nil : CFMotion.snappy, value: referenceDate)
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
        CFGlassCard(padding: 24) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Saldo atual")
                        .font(CFTheme.body())
                        .foregroundStyle(CFTheme.textSecondary)
                    Spacer()
                    CFPillButton(
                        title: monthlyIncomeCents == 0 ? "Definir orçamento" : "Editar orçamento",
                        icon: monthlyIncomeCents == 0 ? "plus.circle" : "pencil",
                        style: .ghost
                    ) {
                        editingIncome.toggle()
                    }
                    .help("Orçamento mensal")
                }

                CFAnimatedAmount(
                    amount: liquidBalance,
                    color: liquidBalance >= 0 ? CFTheme.textPrimary : CFTheme.danger
                )

                HStack(spacing: 14) {
                    CFMetricTile(
                        label: "Entrou no mês",
                        amount: summary.totalIncome,
                        icon: "arrow.down.left",
                        tint: CFTheme.income
                    )
                    Divider().frame(height: 36)
                    CFMetricTile(
                        label: "Saiu no mês",
                        amount: summary.totalExpense,
                        icon: "arrow.up.right",
                        tint: CFTheme.expense
                    )
                    if debtBalance > 0 {
                        Divider().frame(height: 36)
                        CFMetricTile(
                            label: "Em cartões",
                            amount: debtBalance,
                            icon: "creditcard.fill",
                            tint: CFTheme.debt
                        )
                    }
                }
            }
        }
        .popover(isPresented: $editingIncome) {
            MonthlyIncomeEditor(cents: $monthlyIncomeCents)
                .frame(width: 300)
        }
    }
}

private struct MonthlyIncomeEditor: View {
    @Binding var cents: Int
    @State private var amount: Decimal = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Orçamento mensal")
                .font(.headline)
            Text("Quanto você espera ter disponível este mês (salário + outras entradas previstas).")
                .font(.caption)
                .foregroundStyle(CFTheme.textSecondary)
            Text("O CashFlow compara com o que você já gastou e mostra o card de Ritmo, indicando se vai sobrar dinheiro até o fim do mês ou se está gastando rápido demais.")
                .font(.caption)
                .foregroundStyle(CFTheme.textSecondary)
            CurrencyField(amount: $amount, placeholder: "R$ 0,00", style: .form)
                .font(.title3)
            if cents > 0 {
                Button(role: .destructive) {
                    amount = 0
                    cents = 0
                } label: {
                    Label("Remover orçamento", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        CFGlassCard(title: "Ritmo do mês", subtitle: subtitle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: summary.paceState.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(CFTheme.paceColor(for: summary.paceState))
                        .scaleEffect(summary.paceState == .danger ? (pulse ? 1.08 : 1) : 1)
                    Text(summary.paceState.label)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(CFTheme.paceColor(for: summary.paceState))
                }
                .onAppear {
                    updatePulse(for: summary.paceState)
                }
                .onChange(of: summary.paceState) { _, newValue in
                    updatePulse(for: newValue)
                }

                doubleBar
                legend
            }
        }
    }

    private var doubleBar: some View {
        VStack(spacing: 8) {
            CFProgressBar(progress: summary.dayProgress, color: CFTheme.textSecondary.opacity(0.45), height: 8)
            CFProgressBar(progress: min(summary.spentRatio, 1.5), color: CFTheme.paceColor(for: summary.paceState), height: 8)
        }
    }

    private var legend: some View {
        HStack(spacing: 14) {
            legendItem(swatch: CFTheme.textSecondary.opacity(0.45), label: "Mês passou", value: "\(Int(summary.dayProgress * 100))%")
            legendItem(swatch: CFTheme.paceColor(for: summary.paceState), label: "Você gastou", value: "\(Int(summary.spentRatio * 100))%")
            Spacer()
            if summary.daysRemaining > 0 {
                Text("\(summary.dailyBudgetRemaining.brl) por dia até o fim")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(CFTheme.textSecondary)
            }
        }
        .font(.caption)
    }

    private func legendItem(swatch: Color, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(swatch).frame(width: 10, height: 10)
            Text(label).foregroundStyle(CFTheme.textSecondary)
            Text(value).monospacedDigit()
        }
    }

    private var subtitle: String {
        let remaining = summary.daysRemaining
        if remaining == 0 { return "Mês fechado" }
        return "Faltam \(remaining) \(remaining == 1 ? "dia" : "dias")"
    }

    private func updatePulse(for state: PaceState) {
        guard !reduceMotion else {
            pulse = false
            return
        }
        if state == .danger {
            pulse = false
            withAnimation(CFMotion.snappy.repeatForever(autoreverses: true)) {
                pulse = true
            }
        } else {
            pulse = false
        }
    }
}
