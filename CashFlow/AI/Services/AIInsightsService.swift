import Foundation

enum InsightsPrompts {
    static let system = """
    Você gera um resumo mensal de saúde financeira em português do Brasil.
    Formato obrigatório: 2 a 4 bullets, cada um começando com "- " (hífen + espaço).
    Não use títulos, headings (#, ##, ###), numeração (1., 2.) nem blocos de código.
    Pode usar **negrito** dentro do bullet para destacar números importantes.
    Máximo 250 palavras no total. Não dê conselhos de investimento regulados.
    Use os dados de patrimônio, fluxo do mês, ritmo, categorias, contas, metas e contas a pagar quando relevante.
    """
}

@MainActor
enum AIInsightsService {
    static func cachedInsight(monthKey: String) -> String? {
        UserDefaults.standard.string(forKey: UserDefaultsKeys.aiInsightCacheKey(monthKey: monthKey))
    }

    static func cachedInsightDate(monthKey: String) -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: UserDefaultsKeys.aiInsightCachedAtKey(monthKey: monthKey))
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func cacheInsight(_ text: String, monthKey: String) {
        UserDefaults.standard.set(text, forKey: UserDefaultsKeys.aiInsightCacheKey(monthKey: monthKey))
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: UserDefaultsKeys.aiInsightCachedAtKey(monthKey: monthKey))
    }

    static func generateInsight(
        summary: MonthSummary,
        overview: FinancialOverview,
        accounts: [Account],
        bills: [Bill],
        goals: [FinancialGoal],
        transactions: [Transaction],
        previousMonthExpense: Decimal,
        pendingBillsThisMonth: [Bill] = [],
        aiService: AIService
    ) async throws -> String {
        let context = AIContextBuilder.dashboardOverviewSnapshot(
            summary: summary,
            overview: overview,
            accounts: accounts,
            bills: bills,
            goals: goals,
            transactions: transactions,
            previousMonthExpense: previousMonthExpense,
            pendingBillsThisMonth: pendingBillsThisMonth
        )

        return try await aiService.complete(messages: [
            AIMessage(role: .system, content: InsightsPrompts.system),
            AIMessage(role: .user, content: context)
        ], maxTokens: 500)
    }
}
