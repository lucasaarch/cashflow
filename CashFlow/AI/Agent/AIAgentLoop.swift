import Foundation
import os

@MainActor
struct AIAgentLoop {
    static let maxRounds = 6

    /// Tools that don't fetch user financial records (date/context metadata only).
    private static let metaOnlyTools: Set<String> = [
        "get_app_context",
        "get_app_settings",
        "list_categories"
    ]

    let aiService: AIService
    let tools: [AIToolDefinition]
    let temperature: Double
    let maxTokens: Int?

    func run(
        messages: [AIMessage],
        executor: AIToolExecutor,
        onStatus: ((AIAgentStatusUpdate) -> Void)? = nil,
        onPartialContent: ((String) -> Void)? = nil
    ) async throws -> AIAgentRunResult {
        var conversation = messages
        var toolsExecuted = 0
        var nudgedForTools = false
        var executedToolNames = Set<String>()

        AILogger.agent.debug("Run start: messages=\(conversation.count) tools=\(tools.count)")
        for round in 0..<Self.maxRounds {
            onStatus?(AIAgentStatusUpdate(toolName: nil, isExecutingTools: false))

            AILogger.agent.debug("Round \(round + 1): requesting completion")
            let response = try await aiService.completeWithTools(
                messages: conversation,
                tools: tools,
                temperature: temperature,
                maxTokens: maxTokens
            )
            AILogger.agent.debug("Round \(round + 1): completion received toolCalls=\(response.toolCalls.count) contentChars=\(response.content.count)")

            if response.hasToolCalls {
                let assistant = AIMessage(role: .assistant, content: response.content, toolCalls: response.toolCalls)
                conversation.append(assistant)

                for call in response.toolCalls {
                    AILogger.tools.debug("Executing tool=\(call.name, privacy: .public) args=\(call.argumentsJSON, privacy: .public)")
                    onStatus?(AIAgentStatusUpdate(toolName: call.name, isExecutingTools: true))
                    let outcome = executor.execute(call: call)
                    let preview = outcome.resultJSON.prefix(300)
                    AILogger.tools.debug("Tool=\(call.name, privacy: .public) result chars=\(outcome.resultJSON.count) pending=\(outcome.pendingWrite != nil) preview=\(preview, privacy: .public)")
                    conversation.append(AIMessage.toolResult(callID: call.id, toolName: call.name, content: outcome.resultJSON))
                    toolsExecuted += 1
                    executedToolNames.insert(call.name)

                    if let pending = outcome.pendingWrite {
                        AILogger.agent.debug("Pausing for write confirmation tool=\(call.name, privacy: .public)")
                        return AIAgentRunResult(
                            messages: conversation,
                            finalContent: response.content,
                            pendingWrite: pending,
                            awaitingConfirmation: true
                        )
                    }
                }
                continue
            }

            if !response.content.isEmpty {
                let calledSubstantiveTool = executedToolNames.contains { !Self.metaOnlyTools.contains($0) }
                if !tools.isEmpty,
                   !calledSubstantiveTool,
                   !nudgedForTools,
                   let nudge = Self.toolNudge(for: conversation) {
                    AILogger.agent.debug("Nudging model to use tools (executedSoFar=\(executedToolNames.joined(separator: ","), privacy: .public))")
                    conversation.append(AIMessage(role: .assistant, content: response.content))
                    conversation.append(AIMessage(role: .user, content: nudge))
                    nudgedForTools = true
                    continue
                }

                AILogger.agent.debug("Finishing with content. toolsExecuted=\(toolsExecuted)")
                onPartialContent?(response.content)
                return AIAgentRunResult(
                    messages: conversation + [AIMessage(role: .assistant, content: response.content)],
                    finalContent: response.content,
                    pendingWrite: nil,
                    awaitingConfirmation: false
                )
            }

            AILogger.agent.debug("Empty response with no tool calls; breaking loop")
            break
        }

        var finalContent = ""
        for try await chunk in aiService.stream(messages: conversation, temperature: temperature, maxTokens: maxTokens) {
            if !chunk.content.isEmpty {
                finalContent += chunk.content
                onPartialContent?(chunk.content)
            }
            if chunk.isFinished { break }
        }

        return AIAgentRunResult(
            messages: conversation + [AIMessage(role: .assistant, content: finalContent)],
            finalContent: finalContent,
            pendingWrite: nil,
            awaitingConfirmation: false
        )
    }

    func resumeAfterConfirmation(
        messages: [AIMessage],
        pending: AIPendingWriteAction,
        executor: AIToolExecutor,
        onStatus: ((AIAgentStatusUpdate) -> Void)? = nil,
        onPartialContent: ((String) -> Void)? = nil
    ) async throws -> AIAgentRunResult {
        var conversation = messages
        let call = AIToolCall(id: pending.toolCallID, name: pending.toolName, argumentsJSON: pending.argumentsJSON)
        onStatus?(AIAgentStatusUpdate(toolName: pending.toolName, isExecutingTools: true))
        let outcome = executor.execute(call: call, confirmed: true)

        // The conversation already contains a placeholder tool_result with status
        // pending_confirmation for this same tool_use_id. Anthropic rejects two
        // tool_result blocks sharing an id, so replace instead of appending.
        let executedResult = AIMessage.toolResult(callID: call.id, toolName: call.name, content: outcome.resultJSON)
        if let index = conversation.firstIndex(where: { $0.role == .tool && $0.toolCallId == call.id }) {
            conversation[index] = executedResult
        } else {
            conversation.append(executedResult)
        }

        return try await run(
            messages: conversation,
            executor: executor,
            onStatus: onStatus,
            onPartialContent: onPartialContent
        )
    }

    /// Returns a redirect message for the model when it skipped tool use, or
    /// nil if the question is small talk that doesn't need data/actions.
    private static func toolNudge(for conversation: [AIMessage]) -> String? {
        let nudgeMarker = "ferramentas de"
        guard let question = conversation.last(where: {
            $0.role == .user && !$0.content.lowercased().contains(nudgeMarker)
        })?.content.lowercased() else {
            return readNudge
        }
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return readNudge }

        let smallTalk = [
            "que dia", "qual dia", "que data", "qual data", "que horas", "qual hora",
            "obrigad", "valeu", "olá", "ola", "oi ", "oi!", "bom dia", "boa tarde", "boa noite"
        ]
        if smallTalk.contains(where: { trimmed.contains($0) }) { return nil }

        if looksLikeWriteIntent(trimmed) { return writeNudge }
        return readNudge
    }

    private static func looksLikeWriteIntent(_ text: String) -> Bool {
        let writeVerbs = [
            "cria ", "crie ", "criar ", "cadastr", "adicion", "registr", "lança", "lance ", "lançar",
            "pague ", "pagar ", "paguei", "recebi", "marca como pag", "marcar como pag",
            "marca como receb", "marcar como receb", "aport", "resgat", "transferir",
            "transfere", "transfira", "agend", "reagend", "remarc", "mude o vencimento",
            "mudar o vencimento", "adiar", "antecipar", "nova conta a pagar",
            "nova conta a receber", "novo recebimento", "nova despesa",
            "lista de desejos", "desejo", "comprei o", "comprei a"
        ]
        return writeVerbs.contains(where: { text.contains($0) })
    }

    private static let readNudge = "Use as ferramentas de leitura disponíveis (ex.: get_month_summary, search_transactions, list_month_transactions) para consultar os dados reais antes de responder."

    private static let writeNudge = "O usuário pediu uma ação. Chame a ferramenta de escrita correspondente (create_bill, create_receivable, create_transaction, pay_bill, confirm_receivable, record_fund_transfer, pay_card_invoice, reschedule_bill, reschedule_receivable, create_wishlist_item, update_wishlist_item, delete_wishlist_item ou purchase_wishlist_item) com os dados que ele informou. Não responda só em texto — chame a ferramenta."
}
