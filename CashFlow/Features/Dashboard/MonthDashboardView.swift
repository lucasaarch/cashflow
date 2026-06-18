import SwiftUI
import SwiftData

struct MonthDashboardView: View {
    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Bill.dueDate)])
    private var bills: [Bill]

    @Query(sort: [SortDescriptor(\Receivable.expectedDate)])
    private var receivables: [Receivable]

    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .reverse)])
    private var goals: [FinancialGoal]

    @Query(sort: [SortDescriptor(\WishlistItem.createdAt, order: .reverse)])
    private var wishlistItems: [WishlistItem]

    @Query(sort: [SortDescriptor(\RecurringExpense.createdAt)])
    private var recurringExpenses: [RecurringExpense]

    @Query(sort: [SortDescriptor(\RecurringIncome.createdAt)])
    private var recurringIncomes: [RecurringIncome]

    @Query(sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    @Query(filter: #Predicate<AppSettings> { $0.id == "default" })
    private var appSettings: [AppSettings]

    @State private var referenceDate: Date = .now
    @State private var editingIncome = false
    @State private var contentWidth: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.cfLayoutMode) private var layoutMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var usesSingleColumn: Bool {
        if layoutMode == .compact || horizontalSizeClass == .compact {
            return true
        }
        // Unknown width: prefer two columns on regular layouts until measured.
        guard contentWidth > 0 else { return false }
        return contentWidth < Self.twoColumnMinWidth
    }

    /// Minimum content width before the dashboard splits into two columns.
    private static let twoColumnMinWidth: CGFloat = 720

    private var monthlyIncomeCents: Int {
        appSettings.first?.monthlyIncomeCents ?? 0
    }

    private var monthlyIncomeBinding: Binding<Int> {
        Binding(
            get: { appSettings.first?.monthlyIncomeCents ?? 0 },
            set: { appSettings.first?.monthlyIncomeCents = $0 }
        )
    }

    private var summary: MonthSummary {
        MonthSummary(
            referenceDate: referenceDate,
            monthlyIncomeFallback: Decimal(monthlyIncomeCents) / 100,
            transactions: transactions,
            pendingReceivables: receivables
        )
    }

    private var overview: FinancialOverview {
        FinancialOverview(accounts: accounts, transactions: transactions, bills: bills)
    }

    private var highlightsPanel: DashboardHighlightsPanel {
        DashboardHighlightsPanel(
            bills: bills,
            receivables: receivables,
            goals: goals,
            transactions: transactions,
            referenceDate: referenceDate,
            investedThisMonth: summary.investedThisMonth,
            totalInvested: overview.totalInvestedBalance
        )
    }

    private var hasCategoryBreakdown: Bool { !summary.expensesByCategory.isEmpty }
    private var showsPace: Bool { monthlyIncomeCents > 0 }

    private var chartHeight: CGFloat {
        usesSingleColumn ? 200 : 220
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
        CFScrollView {
            dashboardGrid
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cfStaggerAppear(index: 0)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .offset(y: 8)),
                    removal: .opacity
                ))
                .animation(reduceMotion ? nil : CFMotion.gentle, value: referenceDate)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .preference(key: DashboardContentWidthKey.self, value: proxy.size.width)
            }
        }
        .onPreferenceChange(DashboardContentWidthKey.self) { contentWidth = $0 }
        .cfPageBackground()
    }

    private var dashboardGrid: some View {
        Group {
            if usesSingleColumn {
                singleColumnLayout
            } else {
                twoColumnLayout
            }
        }
        .animation(reduceMotion ? nil : CFMotion.gentle, value: usesSingleColumn)
    }

    private var twoColumnLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            dashboardColumn { leftColumn }
            dashboardColumn { rightColumn }
        }
    }

    private var singleColumnLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            leftColumn
            rightColumn
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func dashboardColumn<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var leftColumn: some View {
        DashboardHeroPanel(overview: overview)
            .frame(maxWidth: .infinity, alignment: .leading)

        DashboardMonthPanel(
            summary: summary,
            showsPace: showsPace,
            editingIncome: $editingIncome,
            monthlyIncomeCents: monthlyIncomeBinding
        )
        .id(referenceDate)
        .frame(maxWidth: .infinity, alignment: .leading)

        if !wishlistItems.isEmpty {
            DashboardWishlistPanel(
                referenceDate: referenceDate,
                summary: summary,
                overview: overview,
                wishlistItems: wishlistItems,
                goals: goals,
                transactions: transactions,
                accounts: accounts,
                bills: bills,
                receivables: receivables,
                recurringExpenses: recurringExpenses,
                recurringIncomes: recurringIncomes,
                categories: categories,
                monthlyIncomeCents: monthlyIncomeCents
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if hasCategoryBreakdown {
            CategoryBreakdownCard(
                aggregates: summary.expensesByCategory,
                totalExpense: summary.totalExpense
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        DashboardInvestmentsChartCard(
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            chartHeight: usesSingleColumn ? 140 : 180
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var rightColumn: some View {
        DashboardInsightPanel(
            referenceDate: referenceDate,
            summary: summary,
            overview: overview,
            accounts: accounts,
            bills: bills,
            receivables: receivables,
            goals: goals,
            wishlistItems: wishlistItems,
            transactions: transactions,
            recurringExpenses: recurringExpenses,
            recurringIncomes: recurringIncomes,
            categories: categories,
            monthlyIncomeCents: monthlyIncomeCents
        )

        if highlightsPanel.shouldShow {
            highlightsPanel
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        DashboardCashFlowChartCard(
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            chartHeight: chartHeight
        )
        .frame(maxWidth: .infinity, alignment: .leading)

        DashboardNetWorthChartCard(
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            chartHeight: chartHeight
        )
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct DashboardContentWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
