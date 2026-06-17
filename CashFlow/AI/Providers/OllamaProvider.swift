import Foundation

struct OllamaProvider: AIProvider {
    let id: AIProviderID = .ollama
    private let configuration: AIConfiguration
    private let client: HTTPClient

    init(configuration: AIConfiguration, client: HTTPClient = HTTPClient()) {
        self.configuration = configuration
        self.client = client
    }

    func validateConfiguration() async throws {
        _ = try await listModels()
    }

    func listModels() async throws -> [AIModel] {
        guard let baseURL = configuration.ollamaBaseURL() else {
            throw AIError.notConfigured(.ollama)
        }
        do {
            let response: OllamaTagsResponse = try await client.get(
                OllamaTagsResponse.self,
                url: baseURL.appendingPathComponent("api/tags"),
                timeout: 5
            )
            return response.models.map {
                AIModel(id: $0.model, displayName: $0.name, contextWindow: nil)
            }
        } catch let error as URLError where error.code == .cannotConnectToHost || error.code == .cannotFindHost {
            throw AIError.networkUnavailable(host: configuration.ollamaHost, port: configuration.ollamaPort)
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.networkUnavailable(host: configuration.ollamaHost, port: configuration.ollamaPort)
        }
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        guard let baseURL = configuration.ollamaBaseURL() else {
            throw AIError.notConfigured(.ollama)
        }
        let body = OllamaChatRequest(
            model: request.modelID,
            messages: request.messages.map { OllamaMessage(role: $0.role.rawValue, content: $0.content) },
            stream: false
        )
        let response: OllamaChatResponse = try await client.postJSON(
            OllamaChatResponse.self,
            url: baseURL.appendingPathComponent("api/chat"),
            body: body
        )
        return AICompletionResponse(content: response.message.content)
    }

    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let baseURL = configuration.ollamaBaseURL() else {
                        throw AIError.notConfigured(.ollama)
                    }
                    let body = OllamaChatRequest(
                        model: request.modelID,
                        messages: request.messages.map { OllamaMessage(role: $0.role.rawValue, content: $0.content) },
                        stream: true
                    )
                    let data = try JSONEncoder().encode(body)
                    let stream = client.postStream(
                        url: baseURL.appendingPathComponent("api/chat"),
                        body: data
                    )
                    for try await line in stream {
                        guard let chunkData = line.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(OllamaChatResponse.self, from: chunkData)
                        let content = chunk.message.content
                        if !content.isEmpty {
                            continuation.yield(AIStreamChunk(content: content, isFinished: chunk.isFinished))
                        }
                        if chunk.isFinished {
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
}

private struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
        let model: String
    }

    let models: [Model]
}

private struct OllamaMessage: Encodable {
    let role: String
    let content: String
}

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
}

private struct OllamaChatResponse: Decodable {
    struct Message: Decodable {
        let content: String
    }

    let message: Message
    let done: Bool?

    var isFinished: Bool { done ?? false }
}
