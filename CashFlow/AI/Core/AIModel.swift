import Foundation

struct AIModel: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let contextWindow: Int?
}

enum AIMessageRole: String, Codable {
    case system
    case user
    case assistant
    case tool
}

struct AIMessage: Hashable {
    let role: AIMessageRole
    let content: String
    let toolCalls: [AIToolCall]
    let toolCallId: String?
    let toolName: String?

    init(
        role: AIMessageRole,
        content: String,
        toolCalls: [AIToolCall] = [],
        toolCallId: String? = nil,
        toolName: String? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
        self.toolName = toolName
    }

    static func toolResult(callID: String, toolName: String, content: String) -> AIMessage {
        AIMessage(role: .tool, content: content, toolCallId: callID, toolName: toolName)
    }
}

struct AICompletionRequest {
    let modelID: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int?
    let tools: [AIToolDefinition]

    init(
        modelID: String,
        messages: [AIMessage],
        temperature: Double = 0.4,
        maxTokens: Int? = nil,
        tools: [AIToolDefinition] = []
    ) {
        self.modelID = modelID
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.tools = tools
    }
}

enum AICompletionFinishReason: String {
    case stop
    case toolCalls = "tool_calls"
}

struct AICompletionResponse {
    let content: String
    let toolCalls: [AIToolCall]
    let finishReason: AICompletionFinishReason?

    init(content: String, toolCalls: [AIToolCall] = [], finishReason: AICompletionFinishReason? = .stop) {
        self.content = content
        self.toolCalls = toolCalls
        self.finishReason = finishReason
    }

    var hasToolCalls: Bool { !toolCalls.isEmpty }
}

struct AIStreamChunk {
    let content: String
    let isFinished: Bool
}

struct AIAgentStatusUpdate {
    let toolName: String?
    let isExecutingTools: Bool
}

struct AIAgentRunResult {
    let messages: [AIMessage]
    let finalContent: String
    let pendingWrite: AIPendingWriteAction?
    let awaitingConfirmation: Bool
}
