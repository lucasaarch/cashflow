import SwiftUI
import Charts
import SwiftData

struct ReportsView: View {
    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Bill.dueDate)])
    private var bills: [Bill]

    @State private var period: ReportPeriod = .sixMonths
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var report: ReportBuilder {
        ReportBuilder(
            period: period,
            transactions: transactions,
            accounts: accounts,
            bills: bills
        )
    }

    private var hasCashFlow: Bool {
        !report.cashFlowSeries.allSatisfy { $0.income == 0 && $0.expense == 0 }
    }

    private var hasNetWorth: Bool {
        !report.netWorthSeries.allSatisfy { $0.netWorth == 0 }
    }

    private var hasCategories: Bool { !report.topCategoryExpenses.isEmpty }
    private var hasInvestments: Bool { !report.investmentFlowSeries.allSatisfy { $0.netInvested == 0 } }
    private var hasBills: Bool { !report.pendingBillsByMonth.isEmpty }

    private var periodIncomeTotal: Decimal {
        report.cashFlowSeries.reduce(0) { $0 + $1.income }
    }

    private var periodExpenseTotal: Decimal {
        report.cashFlowSeries.reduce(0) { $0 + $1.expense }
    }

    private var periodBalance: Decimal { periodIncomeTotal - periodExpenseTotal }

    private var currentNetWorth: Decimal {
        report.netWorthSeries.last?.netWorth ?? 0
    }

    private var chartHeight: CGFloat {
        horizontalSizeClass == .compact ? 200 : 280
    }

    private var detailColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 300, maximum: .infinity), spacing: 12)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroPanel

                if hasCashFlow || hasNetWorth {
                    chartsSection
                }

                if hasCategories || hasInvestments || hasBills {
                    detailsGrid
                } else if !hasCashFlow && !hasNetWorth {
                    emptyReportsState
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Relatórios")
        .cfPageBackground()
    }

    // MARK: - Hero

    private var heroPanel: some View {
        CFPanel(padding: 20) {
            ViewThatFits(in: .horizontal) {
                heroHeaderWide
                heroHeaderStacked
            }

            CFPanelDivider()

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                CFStatChip(label: "Receita no período", amount: periodIncomeTotal, tint: CFTheme.income, icon: "arrow.down.left")
                CFStatChip(label: "Despesa no período", amount: periodExpenseTotal, tint: CFTheme.expense, icon: "arrow.up.right")
                CFStatChip(
                    label: "Saldo no período",
                    amount: periodBalance,
                    tint: periodBalance >= 0 ? CFTheme.income : CFTheme.danger,
                    icon: "equal.circle"
                )
                if hasNetWorth {
                    CFStatChip(label: "Patrimônio atual", amount: currentNetWorth, tint: CFTheme.accent, icon: "chart.line.uptrend.xyaxis")
                }
            }

            let cmp = report.monthComparison
            if cmp.incomeDeltaPercent != nil || cmp.expenseDeltaPercent != nil {
                CFPanelDivider()
                HStack(spacing: 10) {
                    comparisonChip(
                        label: "Receita vs mês anterior",
                        amount: cmp.currentIncome,
                        delta: cmp.incomeDeltaPercent,
                        tint: CFTheme.income
                    )
                    comparisonChip(
                        label: "Despesa vs mês anterior",
                        amount: cmp.currentExpense,
                        delta: cmp.expenseDeltaPercent,
                        tint: CFTheme.expense
                    )
                }
            }
        }
    }

    private var heroHeaderWide: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(period.label)
                    .font(CFTheme.caption().weight(.medium))
                    .foregroundStyle(CFTheme.textSecondary)
                    .textCase(.uppercase)
                Text("Panorama financeiro")
                    .font(CFTheme.headline())
                    .foregroundStyle(CFTheme.textPrimary)
            }
            Spacer(minLength: 0)
            Picker("Período", selection: $period) {
                ForEach(ReportPeriod.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)
        }
    }

    private var heroHeaderStacked: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(period.label)
                    .font(CFTheme.caption().weight(.medium))
                    .foregroundStyle(CFTheme.textSecondary)
                    .textCase(.uppercase)
                Text("Panorama financeiro")
                    .font(CFTheme.headline())
                    .foregroundStyle(CFTheme.textPrimary)
            }
            Picker("Período", selection: $period) {
                ForEach(ReportPeriod.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Charts

    @ViewBuilder
    private var chartsSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                if hasCashFlow {
                    cashFlowChart
                        .layoutPriority(hasNetWorth ? 3 : 1)
                }
                if hasNetWorth {
                    netWorthChart
                        .layoutPriority(2)
                }
            }
            VStack(spacing: 12) {
                if hasCashFlow { cashFlowChart }
                if hasNetWorth { netWorthChart }
            }
        }
    }

    private var cashFlowChart: some View {
        CFPanel {
            CFPanelSection(title: "Fluxo de caixa", subtitle: "Receita vs despesa por mês") {
                Chart(report.cashFlowSeries) { point in
                    BarMark(
                        x: .value("Mês", point.month, unit: .month),
                        y: .value("Receita", NSDecimalNumber(decimal: point.income).doubleValue)
                    )
                    .foregroundStyle(CFTheme.income)
                    .position(by: .value("Tipo", "Receita"))

                    BarMark(
                        x: .value("Mês", point.month, unit: .month),
                        y: .value("Despesa", NSDecimalNumber(decimal: point.expense).doubleValue)
                    )
                    .foregroundStyle(CFTheme.expense)
                    .position(by: .value("Tipo", "Despesa"))
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Money.locale))
                    }
                }
                .chartLegend(position: .top, alignment: .trailing)
                .frame(height: chartHeight)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var netWorthChart: some View {
        CFPanel {
            CFPanelSection(title: "Patrimônio", subtitle: "Evolução no período") {
                Chart(report.netWorthSeries) { point in
                    LineMark(
                        x: .value("Mês", point.month, unit: .month),
                        y: .value("Patrimônio", NSDecimalNumber(decimal: point.netWorth).doubleValue)
                    )
                    .foregroundStyle(CFTheme.accent)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Mês", point.month, unit: .month),
                        y: .value("Patrimônio", NSDecimalNumber(decimal: point.netWorth).doubleValue)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [CFTheme.accent.opacity(0.22), CFTheme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Money.locale))
                    }
                }
                .frame(height: chartHeight)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details grid

    private var detailsGrid: some View {
        LazyVGrid(columns: detailColumns, alignment: .leading, spacing: 12) {
            if hasCategories {
                categoriesCard
            }
            if hasInvestments {
                investmentsCard
            }
            if hasBills {
                billsCard
            }
        }
    }

    private var categoriesCard: some View {
        CFPanel {
            CFPanelSection(title: "Categorias", subtitle: "Maiores despesas no período") {
                let maxTotal = report.topCategoryExpenses.map(\.total).max() ?? 1
                VStack(spacing: 10) {
                    ForEach(report.topCategoryExpenses) { item in
                        categoryRow(item: item, maxTotal: maxTotal)
                    }
                }
            }
        }
    }

    private func categoryRow(item: ReportBuilder.CategoryExpensePoint, maxTotal: Decimal) -> some View {
        let ratio = maxTotal > 0 ? NSDecimalNumber(decimal: item.total / maxTotal).doubleValue : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                CFIconBadge(symbolName: item.category.symbolName, tint: CFTheme.expense, size: 28)
                Text(item.category.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(CFTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(item.total.brl)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(CFTheme.textPrimary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CFTheme.expense.opacity(0.12))
                    Capsule()
                        .fill(CFTheme.expense.opacity(0.45))
                        .frame(width: max(4, geo.size.width * ratio))
                }
            }
            .frame(height: 5)
        }
    }

    private var investmentsCard: some View {
        CFPanel {
            CFPanelSection(title: "Aportes e resgates", subtitle: "Líquido por mês") {
                Chart(report.investmentFlowSeries) { point in
                    BarMark(
                        x: .value("Mês", point.month, unit: .month),
                        y: .value("Líquido", NSDecimalNumber(decimal: point.netInvested).doubleValue)
                    )
                    .foregroundStyle(point.netInvested >= 0 ? CFTheme.accent : CFTheme.warning)
                    .cornerRadius(4)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { _ in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Money.locale))
                    }
                }
                .frame(height: horizontalSizeClass == .compact ? 140 : 180)
            }
        }
    }

    private var billsCard: some View {
        CFPanel {
            CFPanelSection(title: "Contas pendentes", subtitle: "Por vencimento") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(report.pendingBillsByMonth) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(monthLabel(group.month))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(CFTheme.textSecondary)
                                Spacer()
                                Text(group.total.brl)
                                    .font(.caption.monospacedDigit().weight(.semibold))
                            }
                            ForEach(group.bills) { bill in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(bill.isOverdue() ? CFTheme.danger : CFTheme.textTertiary.opacity(0.5))
                                        .frame(width: 6, height: 6)
                                    Text(bill.name)
                                        .font(.callout)
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    Text(bill.dueDate.formatted(.dateTime.day().month(.abbreviated).locale(Money.locale)))
                                        .font(.caption2)
                                        .foregroundStyle(bill.isOverdue() ? CFTheme.danger : CFTheme.textTertiary)
                                }
                            }
                        }
                        if group.id != report.pendingBillsByMonth.last?.id {
                            Divider().opacity(0.35)
                        }
                    }
                }
            }
        }
    }

    private var emptyReportsState: some View {
        CFPanel {
            HStack(spacing: 10) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundStyle(CFTheme.textSecondary)
                Text("Registre movimentações para ver os relatórios.")
                    .foregroundStyle(CFTheme.textSecondary)
                Spacer()
            }
            .font(.callout)
        }
    }

    private func comparisonChip(label: String, amount: Decimal, delta: Double?, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(CFTheme.textSecondary)
                .lineLimit(2)
            Text(amount.brl)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
            if let delta {
                Text(String(format: "%+.0f%%", delta))
                    .font(.caption2)
                    .foregroundStyle(delta > 0 ? CFTheme.warning : CFTheme.income)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.07))
        )
    }

    private func monthLabel(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year(.twoDigits).locale(Money.locale)).capitalized
    }
}
