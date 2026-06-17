import Foundation
import SwiftData

@MainActor
final class AIChatService {
    private let aiService: AIService

    init(aiService: AIService) {
        self.aiService = aiService
    }

    func createConversation(in context: ModelContext) -> ChatConversation {
        let conversation = ChatConversation()
        context.insert(conversation)
        return conversation
    }

    func deleteConversation(_ conversation: ChatConversation, in context: ModelContext) {
        context.delete(conversation)
    }

    func deleteAllConversations(_ conversations: [ChatConversation], in context: ModelContext) {
        conversations.forEach { context.delete($0) }
    }

    func sendMessage(
        _ text: String,
        in conversation: ChatConversation,
        transactions: [Transaction],
        accounts: [Account],
        goals: [FinancialGoal] = [],
        monthlyIncomeCents: Int,
        context modelContext: ModelContext
    ) async throws -> UUID? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let userMessage = ChatMessage(role: .user, content: trimmed, conversation: conversation)
        conversation.messages.append(userMessage)
        modelContext.insert(userMessage)
        conversation.updatedAt = .now

        if conversation.title == "Nova conversa" {
            conversation.title = String(trimmed.prefix(40))
        }

        let snapshot = AIContextBuilder.financialSnapshot(
            transactions: transactions,
            accounts: accounts,
            goals: goals,
            monthlyIncomeCents: monthlyIncomeCents
        )

        var messages: [AIMessage] = [
            AIMessage(role: .system, content: ChatPrompts.system)
        ]

        let history = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(20)
            .dropLast()

        for item in history {
            messages.append(AIMessage(role: item.role, content: item.content))
        }

        messages.append(
            AIMessage(
                role: .user,
                content: ChatPrompts.userMessage(question: trimmed, context: snapshot)
            )
        )

        let assistantMessage = ChatMessage(role: .assistant, content: "", conversation: conversation)
        conversation.messages.append(assistantMessage)
        modelContext.insert(assistantMessage)

        for try await chunk in aiService.stream(messages: messages) {
            if !chunk.content.isEmpty {
                assistantMessage.content += chunk.content
            }
            if chunk.isFinished { break }
        }

        conversation.updatedAt = .now
        return assistantMessage.id
    }
}
