import Foundation
import SwiftData

struct AIChatSendResult {
    let assistantMessageID: UUID?
    let pendingWrite: AIPendingWriteAction?
    let agentMessages: [AIMessage]
}

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
        bills: [Bill],
        receivables: [Receivable],
        goals: [FinancialGoal],
        wishlistItems: [WishlistItem],
        recurringExpenses: [RecurringExpense],
        recurringIncomes: [RecurringIncome],
        categories: [Category],
        dashboardInsightMonthKey: String? = nil,
        wishlistInsightMonthKey: String? = nil,
        context modelContext: ModelContext,
        onStatus: ((AIAgentStatusUpdate) -> Void)? = nil,
        onPartialContent: ((String) -> Void)? = nil
    ) async throws -> AIChatSendResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AIChatSendResult(assistantMessageID: nil, pendingWrite: nil, agentMessages: [])
        }

        let userMessage = ChatMessage(role: .user, content: trimmed, conversation: conversation)
        conversation.messages.append(userMessage)
        modelContext.insert(userMessage)
        conversation.updatedAt = .now

        if conversation.title == "Nova conversa" {
            conversation.title = String(trimmed.prefix(40))
        }

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
            dashboardInsightMonthKey: dashboardInsightMonthKey,
            wishlistInsightMonthKey: wishlistInsightMonthKey
        )

        var messages = buildConversationMessages(conversation: conversation, userText: trimmed, toolContext: toolContext)

        let assistantMessage = ChatMessage(role: .assistant, content: "", conversation: conversation)
        conversation.messages.append(assistantMessage)
        modelContext.insert(assistantMessage)

        if aiService.activeProviderSupportsTools {
            let agent = AIAgentLoop(
                aiService: aiService,
                tools: AIToolCatalog.all,
                temperature: 0.4,
                maxTokens: 4096
            )
            let executor = AIToolExecutor(context: toolContext)
            let result = try await agent.run(
                messages: messages,
                executor: executor,
                onStatus: onStatus,
                onPartialContent: { chunk in
                    if assistantMessage.content.isEmpty {
                        assistantMessage.content = chunk
                    } else {
                        assistantMessage.content += chunk
                    }
                    onPartialContent?(chunk)
                }
            )

            applyAssistantContent(result, to: assistantMessage)
            let finalID = pruneIfEmpty(assistantMessage, in: conversation, context: modelContext)

            conversation.updatedAt = .now
            return AIChatSendResult(
                assistantMessageID: finalID,
                pendingWrite: result.pendingWrite,
                agentMessages: result.messages
            )
        }

        // Fallback: snapshot dump for providers without tool support
        return try await streamFallbackResponse(
            messages: &messages,
            assistantMessage: assistantMessage,
            conversation: conversation,
            toolContext: toolContext,
            userText: trimmed,
            onPartialContent: onPartialContent
        )
    }

    func confirmPendingWrite(
        _ pending: AIPendingWriteAction,
        agentMessages: [AIMessage],
        in conversation: ChatConversation,
        transactions: [Transaction],
        accounts: [Account],
        bills: [Bill],
        receivables: [Receivable],
        goals: [FinancialGoal],
        wishlistItems: [WishlistItem],
        recurringExpenses: [RecurringExpense],
        recurringIncomes: [RecurringIncome],
        categories: [Category],
        dashboardInsightMonthKey: String? = nil,
        wishlistInsightMonthKey: String? = nil,
        context modelContext: ModelContext,
        onStatus: ((AIAgentStatusUpdate) -> Void)? = nil,
        onPartialContent: ((String) -> Void)? = nil
    ) async throws -> AIChatSendResult {
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
            dashboardInsightMonthKey: dashboardInsightMonthKey,
            wishlistInsightMonthKey: wishlistInsightMonthKey
        )

        let assistantMessage = ChatMessage(role: .assistant, content: "", conversation: conversation)
        conversation.messages.append(assistantMessage)
        modelContext.insert(assistantMessage)

        let agent = AIAgentLoop(aiService: aiService, tools: AIToolCatalog.all, temperature: 0.4, maxTokens: 4096)
        let executor = AIToolExecutor(context: toolContext)
        let result = try await agent.resumeAfterConfirmation(
            messages: agentMessages,
            pending: pending,
            executor: executor,
            onStatus: onStatus,
            onPartialContent: { chunk in
                assistantMessage.content += chunk
                onPartialContent?(chunk)
            }
        )

        applyAssistantContent(result, to: assistantMessage)
        let finalID = pruneIfEmpty(assistantMessage, in: conversation, context: modelContext)

        conversation.updatedAt = .now
        return AIChatSendResult(
            assistantMessageID: finalID,
            pendingWrite: result.pendingWrite,
            agentMessages: result.messages
        )
    }

    // MARK: - Private

    /// Removes a placeholder assistant message when the model produced no text
    /// (e.g. it only called a tool). Otherwise we'd render an empty bubble.
    private func pruneIfEmpty(_ message: ChatMessage, in conversation: ChatConversation, context: ModelContext) -> UUID? {
        let trimmed = message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return message.id }
        conversation.messages.removeAll { $0.id == message.id }
        context.delete(message)
        return nil
    }

    private func applyAssistantContent(_ result: AIAgentRunResult, to assistantMessage: ChatMessage) {
        guard !result.finalContent.isEmpty else { return }
        if result.awaitingConfirmation, !assistantMessage.content.isEmpty { return }
        assistantMessage.content = Self.stripToolJSONLeakage(result.finalContent)
    }

    /// Smaller local models (e.g. small Qwen) sometimes dump the raw tool-result
    /// JSON into the assistant message. Strip fenced JSON blocks that look like a
    /// tool payload so the user never sees them.
    static func stripToolJSONLeakage(_ text: String) -> String {
        let pattern = #"(?is)```\s*json\b.*?```"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let mutable = NSMutableString(string: text)
        regex.replaceMatches(in: mutable, range: range, withTemplate: "")
        var result = mutable as String
        // Collapse the blank lines left behind by removed blocks.
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func buildConversationMessages(
        conversation: ChatConversation,
        userText: String,
        toolContext: AIToolContext
    ) -> [AIMessage] {
        let systemContent = aiService.activeProviderSupportsTools
            ? ChatPrompts.system(now: toolContext.now)
            : ChatPrompts.systemWithSnapshotFallback(now: toolContext.now)
        var messages: [AIMessage] = [
            AIMessage(role: .system, content: systemContent)
        ]

        let history = conversation.messages
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(20)
            .dropLast()

        for item in history where item.role == .user || item.role == .assistant {
            messages.append(AIMessage(role: item.role, content: item.content))
        }

        if aiService.activeProviderSupportsTools {
            messages.append(AIMessage(role: .user, content: ChatPrompts.userMessage(question: userText)))
        } else {
            let snapshot = AIContextBuilder.financialSnapshot(
                transactions: toolContext.transactions,
                accounts: toolContext.accounts,
                bills: toolContext.bills,
                receivables: toolContext.receivables,
                goals: toolContext.goals,
                recurringExpenses: toolContext.recurringExpenses,
                recurringIncomes: toolContext.recurringIncomes
            )
            messages.append(AIMessage(role: .user, content: ChatPrompts.userMessage(question: userText, context: snapshot)))
        }

        return messages
    }

    private func streamFallbackResponse(
        messages: inout [AIMessage],
        assistantMessage: ChatMessage,
        conversation: ChatConversation,
        toolContext: AIToolContext,
        userText: String,
        onPartialContent: ((String) -> Void)?
    ) async throws -> AIChatSendResult {
        for try await chunk in aiService.stream(messages: messages) {
            if !chunk.content.isEmpty {
                assistantMessage.content += chunk.content
                onPartialContent?(chunk.content)
            }
            if chunk.isFinished { break }
        }
        conversation.updatedAt = .now
        return AIChatSendResult(assistantMessageID: assistantMessage.id, pendingWrite: nil, agentMessages: messages)
    }
}
