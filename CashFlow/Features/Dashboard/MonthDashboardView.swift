import SwiftUI
import SwiftData

struct MonthDashboardView: View {
    @EnvironmentObject private var aiService: AIService

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Bill.dueDate)])
    private var bills: [Bill]

    @Query(sort: [SortDescriptor(\FinancialGoal.createdAt, order: .reverse)])
    private var goals: [FinancialGoal]

    @Query(filter: #Predicate<AppSettings> { $0.id == "default" })
    private var appSettings: [AppSettings]

    @State private var referenceDate: Date = .now
    @State private var editingIncome = false
    @State private var insightText: String?
    @State private var insightLoading = false
    @State private var insightError: String?
    @State private var insightCachedAt: Date?
    @State private var insightIsFresh: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            monthlyIncomeBudget: Decimal(monthlyIncomeCents) / 100,
            transactions: transactions
        )
    }

    private var overview: FinancialOverview {
        FinancialOverview(accounts: accounts, transactions: transactions, bills: bills)
    }

    private var highlightsPanel: DashboardHighlightsPanel {
        DashboardHighlightsPanel(
            bills: bills,
            goals: goals,
            transactions: transactions,
            investedThisMonth: summary.investedThisMonth,
            totalInvested: overview.investmentBalance
        )
    }

    private var analysisPanel: DashboardAnalysisPanel {
        DashboardAnalysisPanel(
            categoryAggregates: summary.expensesByCategory,
            accountAggregates: summary.expensesByAccount,
            totalExpense: summary.totalExpense
        )
    }

    private var pendingBillsThisMonthList: [Bill] {
        let interval = summary.monthInterval
        return bills.filter { $0.isPending && interval.contains($0.dueDate) }
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
            ViewThatFits(in: .horizontal) {
                asideDashboard
                stackedDashboard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Wide: main column left, insight aside right — uses full width.
    private var asideDashboard: some View {
        HStack(alignment: .top, spacing: 16) {
            mainColumn.cfStaggerAppear(index: 0)

            if showsInsight {
                insightAside
                    .frame(width: 340)
                    .cfStaggerAppear(index: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minWidth: 880)
    }

    /// Narrow: stacked, insight after main content.
    private var stackedDashboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            mainColumn.cfStaggerAppear(index: 0)
            if showsInsight {
                insightAside.cfStaggerAppear(index: 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mainColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            DashboardHeroPanel(overview: overview)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    monthAndHighlightsRow
                }
                VStack(alignment: .leading, spacing: 12) {
                    monthAndHighlightsRow
                }
            }

            if analysisPanel.shouldShow {
                analysisPanel
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var monthAndHighlightsRow: some View {
        DashboardMonthPanel(
            summary: summary,
            showsPace: showsPace,
            editingIncome: $editingIncome,
            monthlyIncomeCents: monthlyIncomeBinding
        )
        .frame(maxWidth: .infinity)
        .id(referenceDate)

        if highlightsPanel.shouldShow {
            highlightsPanel
                .frame(maxWidth: .infinity)
        }
    }

    private var insightAside: some View {
        insightPanel
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var showsInsight: Bool { aiService.configuration.isReady }
    private var showsPace: Bool { monthlyIncomeCents > 0 }

    private var insightPanel: some View {
        CFPanel {
            VStack(alignment: .leading, spacing: 12) {
                insightHeader
                insightBody
                if let insightError {
                    Text(insightError)
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.expense)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay {
            if insightIsFresh && !reduceMotion {
                RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                    .stroke(CFTheme.accent.opacity(0.45), lineWidth: 1.2)
                    .blur(radius: 4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : CFMotion.gentle, value: insightIsFresh)
    }

    private var insightHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CFTheme.accent)
                Text("Resumo inteligente")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CFTheme.textPrimary)
                Spacer(minLength: 0)
                if insightText != nil && !insightLoading {
                    Button {
                        Task { await generateInsight(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(CFTheme.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(CFTheme.textTertiary.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Atualizar resumo")
                }
            }
            if let chip = freshnessChip {
                Text(chip)
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var insightBody: some View {
        if insightLoading {
            VStack(alignment: .leading, spacing: 10) {
                CFSkeletonLine(height: 11, widthFraction: 0.95)
                CFSkeletonLine(height: 11, widthFraction: 0.85)
                CFSkeletonLine(height: 11, widthFraction: 0.7)
            }
            .padding(.vertical, 4)
        } else if let insightText {
            CFTypewriter(text: insightText, markdown: true, animated: insightIsFresh)
                .font(.callout)
                .foregroundStyle(CFTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(3)
        } else {
            CFPillButton(title: "Gerar resumo", icon: "sparkles", style: .primary) {
                Task { await generateInsight(force: false) }
            }
        }
    }

    private var freshnessChip: String? {
        guard insightText != nil, let cachedAt = insightCachedAt else { return nil }
        let seconds = Int(Date.now.timeIntervalSince(cachedAt))
        switch seconds {
        case ..<60: return "agora mesmo"
        case 60..<3600:
            let minutes = seconds / 60
            return "há \(minutes) min"
        case 3600..<86400:
            let hours = seconds / 3600
            return "há \(hours)h"
        default:
            let days = seconds / 86400
            return "há \(days)d"
        }
    }

    private var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: referenceDate)
    }

    private func loadCachedInsight() {
        insightText = AIInsightsService.cachedInsight(monthKey: monthKey)
        insightCachedAt = AIInsightsService.cachedInsightDate(monthKey: monthKey)
        insightError = nil
        insightIsFresh = false
    }

    private func generateInsight(force: Bool) async {
        if !force, insightText != nil { return }
        insightLoading = true
        insightError = nil
        insightIsFresh = false
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
                overview: overview,
                accounts: accounts,
                bills: bills,
                goals: goals,
                transactions: transactions,
                previousMonthExpense: previousSummary.totalExpense,
                pendingBillsThisMonth: pendingBillsThisMonthList,
                aiService: aiService
            )
            AIInsightsService.cacheInsight(text, monthKey: monthKey)
            insightText = text
            insightCachedAt = AIInsightsService.cachedInsightDate(monthKey: monthKey)
            insightIsFresh = true
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                insightIsFresh = false
            }
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
