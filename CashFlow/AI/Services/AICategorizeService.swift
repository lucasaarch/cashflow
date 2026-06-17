import Foundation

@MainActor
enum AICategorizeService {
    static func parseTransaction(text: String, aiService: AIService) async throws -> AIParsedTransaction {
        let response = try await aiService.complete(messages: [
            AIMessage(role: .system, content: CategorizePrompts.parseTransaction),
            AIMessage(role: .user, content: text)
        ])
        return try AICategorizeParsing.parseTransactionResponse(response)
    }

    static func suggestCategory(
        amount: Decimal,
        kind: TransactionKind,
        note: String,
        categories: [Category],
        aiService: AIService
    ) async throws -> AICategorySuggestion {
        let options = categories
            .filter { !$0.isArchived }
            .filter { $0.kind == (kind == .income ? .income : .expense) }
            .map { (id: $0.id.uuidString, name: $0.name, kind: $0.kind.rawValue) }

        let prompt = CategorizePrompts.suggestCategory(
            categories: options,
            amount: amount,
            kind: kind.rawValue,
            note: note
        )

        let response = try await aiService.complete(messages: [
            AIMessage(role: .system, content: "Você classifica lançamentos financeiros."),
            AIMessage(role: .user, content: prompt)
        ])
        return try AICategorizeParsing.parseCategorySuggestion(response)
    }
}
