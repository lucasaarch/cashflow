import SwiftUI
import SwiftData

struct DashboardInsightPanel: View {
    @EnvironmentObject private var aiService: AIService
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let referenceDate: Date
    let summary: MonthSummary
    let overview: FinancialOverview
    let accounts: [Account]
    let bills: [Bill]
    let receivables: [Receivable]
    let goals: [FinancialGoal]
    let wishlistItems: [WishlistItem]
    let transactions: [Transaction]
    let recurringExpenses: [RecurringExpense]
    let recurringIncomes: [RecurringIncome]
    let categories: [Category]
    let monthlyIncomeCents: Int

    @State private var insightText: String?
    @State private var insightLoading = false
    @State private var insightError: String?
    @State private var insightCachedAt: Date?
    @State private var insightIsFresh = false

    private var monthKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: referenceDate)
    }

    var body: some View {
        if aiService.configuration.isReady {
            CFPanel {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    bodyContent
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .onAppear(perform: loadCachedInsight)
            .onChange(of: referenceDate) { _, _ in loadCachedInsight() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CFTheme.accent)
                Text("Resumo da \(AIAssistantIdentity.name)")
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
    private var bodyContent: some View {
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
                .lineSpacing(3)
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
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
            monthlyIncomeFallback: Decimal(monthlyIncomeCents) / 100,
            transactions: transactions
        )

        do {
            let text = try await AIInsightsService.generateInsight(
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
                previousMonthExpense: previousSummary.totalExpense,
                monthlyIncomeCents: monthlyIncomeCents,
                modelContext: modelContext,
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
}
