import Foundation
import SwiftData

enum InsightsPrompts {
    static let system = """
    Você gera um resumo mensal de saúde financeira em português do Brasil.
    Formato obrigatório: 2 a 4 bullets, cada um começando com "- " (hífen + espaço).
    Não use títulos, headings (#, ##, ###), numeração (1., 2.) nem blocos de código.
    Pode usar **negrito** dentro do bullet para destacar números importantes.
    Máximo 250 palavras no total. Não dê conselhos de investimento regulados.

    IMPORTANTE — distinção entre realizado e esperado:
    - "Realizado" = dinheiro que JÁ caiu na conta ou JÁ saiu (transações com data ≤ hoje).
    - "Esperado" = realizado + previsto + receivables pendentes. É uma projeção, não o saldo atual.
    - "Saldo realizado do mês" é o que importa pra dizer se a pessoa tá positiva ou negativa AGORA.
    - Nunca diga que o mês tá "favorável" só porque o esperado é maior que o gasto — verifique se o realizado já cobre o que foi gasto.
    - Se o saldo realizado é negativo (gastou mais do que entrou até agora) mesmo com renda esperada alta, isso é um alerta de fluxo de caixa, não folga.

    Use os dados de patrimônio, fluxo do mês (realizado e previsto), ritmo, metas e contas a pagar/receber quando relevante.
    """
}

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

    @MainActor
    static func generateInsight(
        summary: MonthSummary,
        overview: FinancialOverview,
        accounts: [Account],
        bills: [Bill],
        receivables: [Receivable],
        goals: [FinancialGoal],
        wishlistItems: [WishlistItem] = [],
        transactions: [Transaction],
        recurringExpenses: [RecurringExpense],
        recurringIncomes: [RecurringIncome],
        categories: [Category],
        previousMonthExpense: Decimal,
        monthlyIncomeCents: Int,
        modelContext: ModelContext,
        aiService: AIService
    ) async throws -> String {
        let context: String
        if aiService.activeProviderSupportsTools {
            let toolContext = AIToolContext(
                modelContext: modelContext,
                transactions: transactions,
                accounts: accounts,
                bills: bills,
                receivables: receivables,
                goals: goals,
                recurringExpenses: recurringExpenses,
                recurringIncomes: recurringIncomes,
                categories: categories,
                wishlistItems: wishlistItems,
                monthlyIncomeCents: monthlyIncomeCents,
                now: summary.referenceDate
            )
            context = AIToolInsightContext.compactSnapshot(context: toolContext)
        } else {
            context = AIContextBuilder.dashboardOverviewSnapshot(
                summary: summary,
                overview: overview,
                accounts: accounts,
                bills: bills,
                receivables: receivables,
                goals: goals,
                transactions: transactions,
                recurringExpenses: recurringExpenses,
                recurringIncomes: recurringIncomes,
                previousMonthExpense: previousMonthExpense,
                monthlyIncomeCents: monthlyIncomeCents
            )
        }

        return try await aiService.complete(messages: [
            AIMessage(role: .system, content: InsightsPrompts.system),
            AIMessage(role: .user, content: context)
        ], maxTokens: 500)
    }
}
