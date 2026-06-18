import Foundation
import SwiftData

enum WishlistInsightPrompts {
    static let system = """
    Você sugere timing de compras da lista de desejos em português do Brasil.
    Formato: 1 a 2 bullets começando com "- ".
    Máximo 120 palavras. Não dê conselhos de investimento regulados.

    Regras:
    - Identifique itens que cabem na folga discrecional DESTE mês (saldo realizado positivo após obrigações).
    - Destaque itens com desired_by ou desired_in próximo.
    - Se o fluxo estiver apertado, diga para esperar — NÃO empurre compras mesmo de itens urgentes.
    - Não invente valores; use apenas os dados fornecidos.
    """
}

enum AIWishlistInsightService {
    static func cachedInsight(monthKey: String) -> String? {
        UserDefaults.standard.string(forKey: UserDefaultsKeys.aiWishlistInsightCacheKey(monthKey: monthKey))
    }

    static func cachedInsightDate(monthKey: String) -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: UserDefaultsKeys.aiWishlistInsightCachedAtKey(monthKey: monthKey))
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    static func cacheInsight(_ text: String, monthKey: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.set(trimmed, forKey: UserDefaultsKeys.aiWishlistInsightCacheKey(monthKey: monthKey))
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: UserDefaultsKeys.aiWishlistInsightCachedAtKey(monthKey: monthKey))
    }

    static func clearCachedInsight(monthKey: String) {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.aiWishlistInsightCacheKey(monthKey: monthKey))
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.aiWishlistInsightCachedAtKey(monthKey: monthKey))
    }

    @MainActor
    static func generateInsight(
        summary: MonthSummary,
        overview: FinancialOverview,
        wishlistItems: [WishlistItem],
        goals: [FinancialGoal],
        transactions: [Transaction],
        accounts: [Account],
        bills: [Bill],
        receivables: [Receivable],
        recurringExpenses: [RecurringExpense],
        recurringIncomes: [RecurringIncome],
        categories: [Category],
        modelContext: ModelContext,
        aiService: AIService
    ) async throws -> String {
        guard !wishlistItems.isEmpty else { return "" }

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
            now: summary.referenceDate
        )

        let snapshot = AIToolInsightContext.compactSnapshot(context: toolContext)
        let monthLine = "Saldo realizado do mês: \(summary.balance.brl). Disponível líquido: \(overview.liquidBalance.brl). Contas a pagar pendentes: \(overview.pendingBillsTotal.brl)."
        let contextBlock = "\(monthLine)\n\n\(snapshot)"

        return try await aiService.complete(messages: [
            AIMessage(role: .system, content: WishlistInsightPrompts.system),
            AIMessage(role: .user, content: contextBlock)
        ], maxTokens: 300)
    }
}
