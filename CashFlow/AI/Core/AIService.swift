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
        return (try? providerInstance(for: id, requireVerified: true).supportsToolCalls) ?? false
    }

    /// Custom OpenAI-compatible providers stream MCP tool events via `x_tool_call` SSE chunks.
    var activeProviderUsesExternalMCPTools: Bool {
        guard case .custom(let providerID) = configuration.activeProvider,
              let provider = configuration.customProvider(id: providerID) else {
            return false
        }
        return provider.supportsTools
    }

    func listModels(for provider: AIProviderID) async throws -> [AIModel] {
        try await providerInstance(for: provider, requireVerified: false).listModels()
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
            let task = Task {
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
                        try Task.checkCancellation()
                        continuation.yield(chunk)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func activeProvider() throws -> AIProvider {
        guard let id = configuration.activeProvider else {
            throw AIError.noActiveProvider
        }
        return try providerInstance(for: id, requireVerified: true)
    }

    private func providerInstance(for id: AIProviderID, requireVerified: Bool) throws -> AIProvider {
        switch id {
        case .openai:
            guard configuration.isConfigured(.openai) else {
                throw AIError.notConfigured(.openai)
            }
            return OpenAIProvider(configuration: configuration)
        case .anthropic:
            guard configuration.isConfigured(.anthropic) else {
                throw AIError.notConfigured(.anthropic)
            }
            return AnthropicProvider(configuration: configuration)
        case .custom(let providerID):
            guard let customProvider = configuration.customProvider(id: providerID),
                  customProvider.resolvedBaseURL != nil else {
                throw AIError.notConfigured(.custom(providerID))
            }
            if requireVerified, !customProvider.isConfigured {
                throw AIError.notConfigured(.custom(providerID))
            }
            return OpenAICompatibleProvider(customProvider: customProvider)
        }
    }
}
