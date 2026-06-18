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

    @State private var referenceDate: Date = .now
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.cfLayoutMode) private var layoutMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private func usesSingleColumn(availableWidth: CGFloat) -> Bool {
        if layoutMode == .compact || horizontalSizeClass == .compact {
            return true
        }
        guard availableWidth > 0 else { return true }
        return availableWidth < Self.twoColumnMinWidth
    }

    /// Minimum dashboard width that keeps each column readable after padding and spacing.
    private static let twoColumnMinWidth: CGFloat = (500 * 2) + 12 + (16 * 2)

    private var summary: MonthSummary {
        MonthSummary(
            referenceDate: referenceDate,
            transactions: transactions,
            pendingReceivables: receivables
        )
    }

    private var previousSummary: MonthSummary {
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        return MonthSummary(
            referenceDate: previousMonth,
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
    private var showsPace: Bool { summary.expectedIncome > 0 }

    private func chartHeight(isSingleColumn: Bool) -> CGFloat {
        isSingleColumn ? 200 : 220
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
        GeometryReader { proxy in
            let isSingleColumn = usesSingleColumn(availableWidth: proxy.size.width)

            CFScrollView {
                dashboardGrid(isSingleColumn: isSingleColumn)
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
            .cfPageBackground()
        }
    }

    private func dashboardGrid(isSingleColumn: Bool) -> some View {
        Group {
            if isSingleColumn {
                singleColumnLayout(isSingleColumn: isSingleColumn)
            } else {
                twoColumnLayout(isSingleColumn: isSingleColumn)
            }
        }
        .animation(reduceMotion ? nil : CFMotion.gentle, value: isSingleColumn)
    }

    private func twoColumnLayout(isSingleColumn: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            dashboardColumn { leftColumn(isSingleColumn: isSingleColumn) }
            dashboardColumn { rightColumn(isSingleColumn: isSingleColumn) }
        }
    }

    private func singleColumnLayout(isSingleColumn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            leftColumn(isSingleColumn: isSingleColumn)
            rightColumn(isSingleColumn: isSingleColumn)
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
    private func leftColumn(isSingleColumn: Bool) -> some View {
        DashboardHeroPanel(overview: overview)
            .frame(maxWidth: .infinity, alignment: .leading)

        DashboardMonthPanel(
            summary: summary,
            showsPace: showsPace
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
                categories: categories
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        DashboardCategoryTrendsPanel(
            currentSummary: summary,
            previousSummary: previousSummary
        )
        .frame(maxWidth: .infinity, alignment: .leading)

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
            chartHeight: isSingleColumn ? 140 : 180
        )
        .frame(maxWidth: .infinity, alignment: .leading)

        DashboardCashFlowChartCard(
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            chartHeight: chartHeight(isSingleColumn: isSingleColumn)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rightColumn(isSingleColumn: Bool) -> some View {
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
            categories: categories
        )

        DashboardInboxPanel(
            summary: summary,
            overview: overview,
            bills: bills,
            receivables: receivables,
            wishlistItems: wishlistItems,
            referenceDate: referenceDate
        )
        .frame(maxWidth: .infinity, alignment: .leading)

        DashboardProjectionPanel(
            summary: summary,
            overview: overview,
            bills: bills,
            receivables: receivables,
            referenceDate: referenceDate
        )
        .frame(maxWidth: .infinity, alignment: .leading)

        DashboardRecoveryPlanPanel(
            summary: summary,
            overview: overview,
            bills: bills,
            receivables: receivables,
            wishlistItems: wishlistItems
        )
        .frame(maxWidth: .infinity, alignment: .leading)

        if highlightsPanel.shouldShow {
            highlightsPanel
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        DashboardNetWorthChartCard(
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            chartHeight: chartHeight(isSingleColumn: isSingleColumn)
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

