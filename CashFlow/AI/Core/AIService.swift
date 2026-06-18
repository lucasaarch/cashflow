import Combine
import Foundation
import SwiftUI

@MainActor
final class AIService: ObservableObject {
    let configuration: AIConfiguration

    init(configuration: AIConfiguration? = nil) {
        self.configuration = configuration ?? AIConfiguration()
    }

    var activeProviderSupportsTools: Bool {
        guard let id = configuration.activeProvider else { return false }
        return (try? makeProvider(id).supportsToolCalls) ?? false
    }

    func listModels(for provider: AIProviderID) async throws -> [AIModel] {
        try await makeProvider(provider).listModels()
    }

    func complete(messages: [AIMessage], temperature: Double = 0.4, maxTokens: Int? = nil) async throws -> String {
        let response = try await completeWithTools(
            messages: messages,
            tools: [],
            temperature: temperature,
            maxTokens: maxTokens
        )
        return response.content
    }

    func completeWithTools(
        messages: [AIMessage],
        tools: [AIToolDefinition],
        temperature: Double = 0.4,
        maxTokens: Int? = nil
    ) async throws -> AICompletionResponse {
        let provider = try activeProvider()
        guard let modelID = configuration.activeModelID else {
            throw AIError.noActiveProvider
        }
        let request = AICompletionRequest(
            modelID: modelID,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            tools: tools
        )
        return try await provider.complete(request)
    }

    func stream(messages: [AIMessage], temperature: Double = 0.4, maxTokens: Int? = nil) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let provider = try activeProvider()
                    guard let modelID = configuration.activeModelID else {
                        throw AIError.noActiveProvider
                    }
                    let request = AICompletionRequest(
                        modelID: modelID,
                        messages: messages,
                        temperature: temperature,
                        maxTokens: maxTokens
                    )
                    for try await chunk in provider.stream(request) {
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func activeProvider() throws -> AIProvider {
        guard let id = configuration.activeProvider else {
            throw AIError.noActiveProvider
        }
        return try makeProvider(id)
    }

    private func makeProvider(_ id: AIProviderID) throws -> AIProvider {
        guard configuration.isConfigured(id) else {
            throw AIError.notConfigured(id)
        }
        switch id {
        case .openai:
            return OpenAIProvider(configuration: configuration)
        case .anthropic:
            return AnthropicProvider(configuration: configuration)
        case .ollama:
            return OllamaProvider(configuration: configuration)
        }
    }
}
