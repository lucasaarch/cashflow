import SwiftUI
import SwiftData

struct DashboardWishlistPanel: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let referenceDate: Date
    let summary: MonthSummary
    let overview: FinancialOverview
    let wishlistItems: [WishlistItem]
    let goals: [FinancialGoal]
    let transactions: [Transaction]
    let accounts: [Account]
    let bills: [Bill]
    let receivables: [Receivable]
    let recurringExpenses: [RecurringExpense]
    let recurringIncomes: [RecurringIncome]
    let categories: [Category]

    @State private var insightText: String?
    @State private var insightLoading = false
    @State private var insightError: String?
    @State private var insightCachedAt: Date?
    @State private var insightIsFresh = false
    @State private var autoRefreshTask: Task<Void, Never>?

    private var monthKey: String {
        AIInsightsService.monthKey(for: referenceDate)
    }

    private var hasCachedInsight: Bool {
        AIWishlistInsightService.cachedInsight(monthKey: monthKey) != nil
    }

    private var displayInsight: String? {
        if let insightText { return insightText }
        return AIWishlistInsightService.cachedInsight(monthKey: monthKey)
    }

    var body: some View {
        if wishlistItems.isEmpty {
            EmptyView()
        } else {
            panelContent
        }
    }

    private var panelContent: some View {
        CFPanel {
            VStack(alignment: .leading, spacing: 14) {
                panelHeader

                if aiService.configuration.isReady || hasCachedInsight {
                    gioSection
                    if let insightError {
                        Text(insightError)
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.expense)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(reduceMotion ? nil : CFMotion.gentle, value: insightIsFresh)
        .onAppear(perform: loadCachedInsightDeferred)
        .onChange(of: referenceDate) { _, _ in loadCachedInsightDeferred() }
        .onChange(of: wishlistItems.count) { _, _ in loadCachedInsightDeferred() }
        .onChange(of: aiService.configuration.isReady) { _, _ in loadCachedInsightDeferred() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { loadCachedInsightDeferred() }
        }
        .onDisappear {
            autoRefreshTask?.cancel()
            autoRefreshTask = nil
        }
    }

    private var panelHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "bag.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CFTheme.accent)
            Text("Recomendações de compra")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CFTheme.textPrimary)
            Spacer(minLength: 0)
            if let chip = freshnessChip {
                Text(chip)
                    .font(CFTheme.dashboardMeta())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            if displayInsight != nil, !insightLoading, aiService.configuration.isReady {
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
                .help("Atualizar sugestão da \(AIAssistantIdentity.name)")
            }
        }
    }

    @ViewBuilder
    private var gioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if insightLoading {
                CFThinkingDots(style: .panel)
                    .padding(.vertical, 4)
            } else if let displayInsight, !displayInsight.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    CFMarkdownText(text: displayInsight, lineSpacing: 3)

                    if aiService.configuration.isReady {
                        CFPillButton(title: "Conversar sobre isso", icon: "bubble.left.and.text.bubble.right", style: .ghost) {
                            chatPanelState.openToDiscussWishlistInsight(referenceDate: referenceDate)
                        }
                    }
                }
            } else if aiService.configuration.isReady {
                CFPillButton(title: "Gerar sugestão", icon: "sparkles", style: .ghost) {
                    Task { await generateInsight(force: false) }
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 4)
    }

    private var freshnessChip: String? {
        guard displayInsight != nil else { return nil }
        return AIInsightCache.freshnessLabel(cachedAt: insightCachedAt)
    }

    private func loadCachedInsightDeferred() {
        Task { @MainActor in
            loadCachedInsight()
            scheduleAutoRefreshIfNeeded()
        }
    }

    private func loadCachedInsight() {
        insightText = AIWishlistInsightService.cachedInsight(monthKey: monthKey)
        insightCachedAt = AIWishlistInsightService.cachedInsightDate(monthKey: monthKey)
        insightError = nil
        insightIsFresh = false
    }

    private func scheduleAutoRefreshIfNeeded() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task { @MainActor in
            await refreshIfNeeded()
        }
    }

    private func refreshIfNeeded() async {
        guard !wishlistItems.isEmpty else { return }
        guard aiService.configuration.isReady else { return }
        guard !insightLoading else { return }
        guard !Task.isCancelled else { return }

        if insightText == nil {
            await generateInsight(force: false)
        } else if AIInsightCache.isStale(cachedAt: insightCachedAt) {
            await generateInsight(force: true)
        }
    }

    private func generateInsight(force: Bool) async {
        guard !wishlistItems.isEmpty else { return }
        if !force, insightText != nil { return }
        insightLoading = true
        insightError = nil
        insightIsFresh = false
        defer { insightLoading = false }

        do {
            let text = try await AIWishlistInsightService.generateInsight(
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
                modelContext: modelContext,
                aiService: aiService
            )
            AIWishlistInsightService.cacheInsight(text, monthKey: monthKey)
            insightText = AIWishlistInsightService.cachedInsight(monthKey: monthKey)
            insightCachedAt = AIWishlistInsightService.cachedInsightDate(monthKey: monthKey)
            insightIsFresh = true
            Task {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                insightIsFresh = false
            }
        } catch {
            insightError = error.localizedDescription
        }
    }
}
