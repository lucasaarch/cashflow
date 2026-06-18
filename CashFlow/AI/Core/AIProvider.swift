import Foundation

protocol AIProvider {
    var id: AIProviderID { get }
    var supportsToolCalls: Bool { get }
    func validateConfiguration() async throws
    func listModels() async throws -> [AIModel]
    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse
    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error>
}

extension AIProvider {
    var supportsToolCalls: Bool { true }
}
