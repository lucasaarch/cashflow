import Foundation

enum InsightsPrompts {
    static let system = """
    Você gera um resumo mensal de saúde financeira em português do Brasil. \
    Use 2 a 4 bullets objetivos e no máximo 250 palavras. Não dê conselhos de investimento regulados.
    """
}

@MainActor
enum AIInsightsService {
    static func cachedInsight(monthKey: String) -> String? {
        UserDefaults.standard.string(forKey: UserDefaultsKeys.aiInsightCacheKey(monthKey: monthKey))
    }

    static func cacheInsight(_ text: String, monthKey: String) {
        UserDefaults.standard.set(text, forKey: UserDefaultsKeys.aiInsightCacheKey(monthKey: monthKey))
    }

    static func generateInsight(
        summary: MonthSummary,
        transactions: [Transaction],
        previousMonthExpense: Decimal,
        aiService: AIService
    ) async throws -> String {
        let context = """
        Mês: \(summary.referenceDate.formatted(.dateTime.month(.wide).year()))
        Receitas: \(summary.totalIncome.brl)
        Despesas: \(summary.totalExpense.brl)
        Orçamento: \(summary.monthlyIncomeBudget.brl)
        Ritmo gasto: \(Int(summary.spentRatio * 100))%
        Despesa mês anterior: \(previousMonthExpense.brl)
        Lançamentos:
        \(transactions.map { "- \($0.occurredOn.formatted(date: .abbreviated, time: .omitted)) \($0.amount.brl) \($0.category?.name ?? "")" }.joined(separator: "\n"))
        """

        return try await aiService.complete(messages: [
            AIMessage(role: .system, content: InsightsPrompts.system),
            AIMessage(role: .user, content: context)
        ], maxTokens: 500)
    }
}
