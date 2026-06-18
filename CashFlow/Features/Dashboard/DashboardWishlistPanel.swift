import SwiftUI
import SwiftData

struct DashboardWishlistPanel: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    let monthlyIncomeCents: Int

    @State private var insightText: String?
    @State private var insightLoading = false
    @State private var insightError: String?
    @State private var insightIsFresh = false

    private var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: referenceDate)
    }

    private var totalEstimated: Decimal {
        wishlistItems.reduce(0) { $0 + $1.estimatedAmount }
    }

    private var sortedItems: [WishlistItem] {
        WishlistSortOrder.sorted(wishlistItems)
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

                WishlistSummaryHeader(totalEstimated: totalEstimated, items: wishlistItems)

                itemsList

                if aiService.configuration.isReady {
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
        .overlay {
            if insightIsFresh && !reduceMotion {
                RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                    .stroke(CFTheme.accent.opacity(0.35), lineWidth: 1.2)
                    .blur(radius: 4)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : CFMotion.gentle, value: insightIsFresh)
        .onAppear(perform: loadCachedInsight)
        .onChange(of: referenceDate) { _, _ in loadCachedInsight() }
        .onChange(of: wishlistItems.count) { _, _ in loadCachedInsight() }
    }

    private var panelHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "cart.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(CFTheme.accent)
            Text("Lista de desejos")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CFTheme.textPrimary)
            Spacer(minLength: 0)
            if insightText != nil, !insightLoading, aiService.configuration.isReady {
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

    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sortedItems) { item in
                CFHoverRow {
                    WishlistItemRow(
                        item: item,
                        iconSize: 30,
                        nameFont: CFTheme.body(),
                        amountFont: CFTheme.kpiValue()
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var gioSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sugestão da \(AIAssistantIdentity.name)")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            if insightLoading {
                VStack(alignment: .leading, spacing: 10) {
                    CFSkeletonLine(height: 11, widthFraction: 0.9)
                    CFSkeletonLine(height: 11, widthFraction: 0.75)
                }
                .padding(.vertical, 4)
            } else if let insightText, !insightText.isEmpty {
                CFTypewriter(text: insightText, markdown: true, animated: insightIsFresh)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                    .lineSpacing(3)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            } else {
                CFPillButton(title: "Gerar sugestão", icon: "sparkles", style: .ghost) {
                    Task { await generateInsight(force: false) }
                }
            }
        }
        .padding(.top, 4)
    }

    private func loadCachedInsight() {
        insightText = AIWishlistInsightService.cachedInsight(monthKey: monthKey)
        insightError = nil
        insightIsFresh = false
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
                monthlyIncomeCents: monthlyIncomeCents,
                modelContext: modelContext,
                aiService: aiService
            )
            AIWishlistInsightService.cacheInsight(text, monthKey: monthKey)
            insightText = text
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
