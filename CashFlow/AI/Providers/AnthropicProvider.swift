import Foundation

struct AnthropicProvider: AIProvider {
    let id: AIProviderID = .anthropic
    private let configuration: AIConfiguration
    private let client: HTTPClient

    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let apiVersion = "2023-06-01"

    private let curatedModels: [AIModel] = [
        AIModel(id: "claude-sonnet-4-20250514", displayName: "Claude Sonnet 4", contextWindow: 200_000),
        AIModel(id: "claude-3-5-haiku-20241022", displayName: "Claude 3.5 Haiku", contextWindow: 200_000)
    ]

    init(configuration: AIConfiguration, client: HTTPClient = HTTPClient()) {
        self.configuration = configuration
        self.client = client
    }

    func validateConfiguration() async throws {
        guard apiKey != nil else { throw AIError.notConfigured(.anthropic) }
    }

    func listModels() async throws -> [AIModel] {
        guard apiKey != nil else { throw AIError.notConfigured(.anthropic) }
        return curatedModels
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        guard let apiKey else { throw AIError.notConfigured(.anthropic) }
        let system = request.messages.first(where: { $0.role == .system })?.content
        let messages = request.messages
            .filter { $0.role != .system }
            .map { AnthropicMessage(role: $0.role == .assistant ? "assistant" : "user", content: $0.content) }
        let body = AnthropicRequest(
            model: request.modelID,
            max_tokens: request.maxTokens ?? 1024,
            system: system,
            messages: messages,
            temperature: request.temperature,
            stream: false
        )
        let response: AnthropicResponse = try await client.postJSON(
            AnthropicResponse.self,
            url: baseURL.appendingPathComponent("messages"),
            body: body,
            headers: authHeaders(apiKey)
        )
        guard let text = response.content.first(where: { $0.type == "text" })?.text else {
            throw AIError.decodingFailed
        }
        return AICompletionResponse(content: text)
    }

    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey else { throw AIError.notConfigured(.anthropic) }
                    let system = request.messages.first(where: { $0.role == .system })?.content
                    let messages = request.messages
                        .filter { $0.role != .system }
                        .map { AnthropicMessage(role: $0.role == .assistant ? "assistant" : "user", content: $0.content) }
                    let body = AnthropicRequest(
                        model: request.modelID,
                        max_tokens: request.maxTokens ?? 1024,
                        system: system,
                        messages: messages,
                        temperature: request.temperature,
                        stream: true
                    )
                    let data = try JSONEncoder().encode(body)
                    let stream = client.postStream(
                        url: baseURL.appendingPathComponent("messages"),
                        body: data,
                        headers: authHeaders(apiKey)
                    )
                    for try await line in stream {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard let chunkData = json.data(using: .utf8) else { continue }
                        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: chunkData)
                        if event.type == "content_block_delta", let text = event.delta?.text, !text.isEmpty {
                            continuation.yield(AIStreamChunk(content: text, isFinished: false))
                        }
                        if event.type == "message_stop" {
                            continuation.yield(AIStreamChunk(content: "", isFinished: true))
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private var apiKey: String? { SecureStore.read(.anthropicAPIKey) }

    private func authHeaders(_ apiKey: String) -> [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": apiVersion
        ]
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: String
}

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    let temperature: Double
    let stream: Bool
}

private struct AnthropicResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }

    let content: [Block]
}

private struct AnthropicStreamEvent: Decodable {
    struct Delta: Decodable { let text: String? }
    let type: String
    let delta: Delta?
}
