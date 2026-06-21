import Foundation

struct OpenAICompatibleProvider: AIProvider {
    let customProvider: CustomAIProvider
    private let client: HTTPClient

    var id: AIProviderID { .custom(customProvider.id) }
    var supportsToolCalls: Bool { customProvider.supportsTools }

    init(customProvider: CustomAIProvider, client: HTTPClient = HTTPClient()) {
        self.customProvider = customProvider
        self.client = client
    }

    func validateConfiguration() async throws {
        guard let baseURL = customProvider.resolvedBaseURL else {
            throw AIError.notConfigured(.custom(customProvider.id))
        }
        _ = try await chatClient(baseURL: baseURL).listModels()
    }

    func listModels() async throws -> [AIModel] {
        guard let baseURL = customProvider.resolvedBaseURL else {
            throw AIError.notConfigured(.custom(customProvider.id))
        }
        return try await chatClient(baseURL: baseURL).listModels()
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        guard let baseURL = customProvider.resolvedBaseURL else {
            throw AIError.notConfigured(.custom(customProvider.id))
        }
        return try await chatClient(baseURL: baseURL).complete(request)
    }

    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        guard let baseURL = customProvider.resolvedBaseURL else {
            return AsyncThrowingStream {
                $0.finish(throwing: AIError.notConfigured(.custom(customProvider.id)))
            }
        }
        return chatClient(baseURL: baseURL).stream(request)
    }

    private func chatClient(baseURL: URL) -> OpenAIChatClient {
        OpenAIChatClient(
            baseURL: baseURL,
            apiKey: SecureStore.readCustomProviderAPIKey(customProvider.id),
            client: client,
            modelFilter: { _ in true }
        )
    }
}
