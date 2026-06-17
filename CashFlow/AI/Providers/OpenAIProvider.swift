import Foundation

struct OpenAIProvider: AIProvider {
    let id: AIProviderID = .openai
    private let configuration: AIConfiguration
    private let client: HTTPClient

    private let baseURL = URL(string: "https://api.openai.com/v1")!

    init(configuration: AIConfiguration, client: HTTPClient = HTTPClient()) {
        self.configuration = configuration
        self.client = client
    }

    func validateConfiguration() async throws {
        guard apiKey != nil else { throw AIError.notConfigured(.openai) }
        _ = try await listModels()
    }

    func listModels() async throws -> [AIModel] {
        guard let apiKey else { throw AIError.notConfigured(.openai) }
        let response: OpenAIModelsResponse = try await client.get(
            OpenAIModelsResponse.self,
            url: baseURL.appendingPathComponent("models"),
            headers: authHeaders(apiKey)
        )
        return response.data
            .map(\.id)
            .filter { $0.contains("gpt") || $0.hasPrefix("o") }
            .sorted()
            .map { AIModel(id: $0, displayName: $0, contextWindow: nil) }
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        guard let apiKey else { throw AIError.notConfigured(.openai) }
        let body = OpenAIChatRequest(
            model: request.modelID,
            messages: request.messages.map { OpenAIMessage(role: $0.role.rawValue, content: $0.content) },
            temperature: request.temperature,
            stream: false
        )
        let response: OpenAIChatResponse = try await client.postJSON(
            OpenAIChatResponse.self,
            url: baseURL.appendingPathComponent("chat/completions"),
            body: body,
            headers: authHeaders(apiKey)
        )
        guard let content = response.choices.first?.message.content else {
            throw AIError.decodingFailed
        }
        return AICompletionResponse(content: content)
    }

    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey else { throw AIError.notConfigured(.openai) }
                    let body = OpenAIChatRequest(
                        model: request.modelID,
                        messages: request.messages.map { OpenAIMessage(role: $0.role.rawValue, content: $0.content) },
                        temperature: request.temperature,
                        stream: true
                    )
                    let data = try JSONEncoder().encode(body)
                    let stream = client.postStream(
                        url: baseURL.appendingPathComponent("chat/completions"),
                        body: data,
                        headers: authHeaders(apiKey)
                    )
                    for try await line in stream {
                        guard line.hasPrefix("data: "), line != "data: [DONE]" else { continue }
                        let json = String(line.dropFirst(6))
                        guard let chunkData = json.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(OpenAIStreamResponse.self, from: chunkData)
                        if let content = chunk.choices.first?.delta.content, !content.isEmpty {
                            continuation.yield(AIStreamChunk(content: content, isFinished: false))
                        }
                    }
                    continuation.yield(AIStreamChunk(content: "", isFinished: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private var apiKey: String? { SecureStore.read(.openAIAPIKey) }

    private func authHeaders(_ apiKey: String) -> [String: String] {
        ["Authorization": "Bearer \(apiKey)"]
    }
}

private struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable { let id: String }
    let data: [Model]
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: String
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let stream: Bool
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message
    }

    let choices: [Choice]
}

private struct OpenAIStreamResponse: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable { let content: String? }
        let delta: Delta
    }

    let choices: [Choice]
}
