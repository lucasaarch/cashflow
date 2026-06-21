import Foundation

struct OpenAIProvider: AIProvider {
    let id: AIProviderID = .openai

    private let client: HTTPClient

    init(configuration: AIConfiguration, client: HTTPClient = HTTPClient()) {
        self.client = client
    }

    func validateConfiguration() async throws {
        guard apiKey != nil else { throw AIError.notConfigured(.openai) }
        _ = try await listModels()
    }

    func listModels() async throws -> [AIModel] {
        guard apiKey != nil else { throw AIError.notConfigured(.openai) }
        return try await makeChatClient().listModels()
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        guard apiKey != nil else { throw AIError.notConfigured(.openai) }
        return try await makeChatClient().complete(request)
    }

    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard apiKey != nil else { throw AIError.notConfigured(.openai) }
                    for try await chunk in makeChatClient().stream(request) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private var apiKey: String? { SecureStore.read(.openAIAPIKey) }

    private func makeChatClient() -> OpenAIChatClient {
        OpenAIChatClient(
            baseURL: URL(string: "https://api.openai.com/v1")!,
            apiKey: apiKey,
            client: client,
            modelFilter: { $0.contains("gpt") || $0.hasPrefix("o") }
        )
    }
}
