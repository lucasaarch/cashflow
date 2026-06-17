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
}

struct AIMessage: Hashable {
    let role: AIMessageRole
    let content: String
}

struct AICompletionRequest {
    let modelID: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int?

    init(modelID: String, messages: [AIMessage], temperature: Double = 0.4, maxTokens: Int? = nil) {
        self.modelID = modelID
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

struct AICompletionResponse {
    let content: String
}

struct AIStreamChunk {
    let content: String
    let isFinished: Bool
}
