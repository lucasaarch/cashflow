import Combine
import Foundation
import SwiftUI

@MainActor
final class AIService: ObservableObject {
    let configuration: AIConfiguration

    init(configuration: AIConfiguration = AIConfiguration()) {
        self.configuration = configuration
    }

    func listModels(for provider: AIProviderID) async throws -> [AIModel] {
        try await makeProvider(provider).listModels()
    }

    func complete(messages: [AIMessage], temperature: Double = 0.4, maxTokens: Int? = nil) async throws -> String {
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
        let response = try await provider.complete(request)
        return response.content
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
