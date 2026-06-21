import Foundation

struct OpenAIChatClient {
    let baseURL: URL
    let apiKey: String?
    let client: HTTPClient
    let modelFilter: (String) -> Bool

    func listModels() async throws -> [AIModel] {
        do {
            let response: OpenAIModelsResponse = try await client.get(
                OpenAIModelsResponse.self,
                url: endpoint("models"),
                headers: authHeaders
            )
            return response.data
                .map(\.id)
                .filter(modelFilter)
                .sorted()
                .map { AIModel(id: $0, displayName: $0, contextWindow: nil) }
        } catch {
            throw mapTransportError(error)
        }
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        do {
            let body = OpenAIChatRequest(
                model: request.modelID,
                messages: request.messages.map { OpenAIMessage(message: $0) },
                temperature: request.temperature,
                stream: false,
                tools: request.tools.isEmpty ? nil : request.tools.map { OpenAITool(definition: $0) }
            )
            let response: OpenAIChatResponse = try await client.postJSON(
                OpenAIChatResponse.self,
                url: endpoint("chat/completions"),
                body: body,
                headers: authHeaders
            )
            guard let choice = response.choices.first else {
                throw AIError.decodingFailed
            }
            let message = choice.message
            let toolCalls = (message.tool_calls ?? []).map {
                AIToolCall(id: $0.id, name: $0.function.name, argumentsJSON: $0.function.arguments)
            }
            if !toolCalls.isEmpty {
                return AICompletionResponse(
                    content: message.content ?? "",
                    toolCalls: toolCalls,
                    finishReason: .toolCalls
                )
            }
            guard let content = message.content else {
                throw AIError.decodingFailed
            }
            return AICompletionResponse(content: content)
        } catch let error as AIError {
            throw error
        } catch {
            throw mapTransportError(error)
        }
    }

    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = OpenAIChatRequest(
                        model: request.modelID,
                        messages: request.messages.map { OpenAIMessage(message: $0) },
                        temperature: request.temperature,
                        stream: true,
                        tools: nil
                    )
                    let data = try JSONEncoder().encode(body)
                    var parser = OpenAIStreamEventParser()
                    let stream = client.postStream(
                        url: endpoint("chat/completions"),
                        body: data,
                        headers: authHeaders
                    )
                    for try await line in stream {
                        guard let chunk = parser.parseSSELine(line) else { continue }
                        if let event = chunk.toolCallEvent {
                            continuation.yield(AIStreamChunk(toolCallEvent: event))
                        }
                        if !chunk.content.isEmpty {
                            continuation.yield(AIStreamChunk(content: chunk.content))
                        }
                        if chunk.isFinished {
                            continuation.yield(AIStreamChunk(isFinished: true))
                            break
                        }
                    }
                    continuation.yield(AIStreamChunk(isFinished: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: mapTransportError(error))
                }
            }
        }
    }

    private var authHeaders: [String: String] {
        guard let apiKey, !apiKey.isEmpty else { return [:] }
        return ["Authorization": "Bearer \(apiKey)"]
    }

    private func endpoint(_ path: String) -> URL {
        baseURL.appending(path: path)
    }

    private func mapTransportError(_ error: Error) -> Error {
        guard let urlError = error as? URLError else { return error }
        switch urlError.code {
        case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .timedOut:
            if let host = baseURL.host {
                let port = baseURL.port ?? (baseURL.scheme == "https" ? 443 : 80)
                return AIError.networkUnavailable(host: host, port: port)
            }
            return AIError.providerError("Não foi possível conectar ao servidor.")
        default:
            return error
        }
    }
}

enum OpenAIBaseURLNormalizer: Sendable {
    nonisolated static let defaultCompatibleURL = "http://127.0.0.1:11434"

    nonisolated static func normalize(_ raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if !trimmed.contains("://") {
            trimmed = "http://\(trimmed)"
        }
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme,
              scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty else {
            return nil
        }

        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if !path.hasSuffix("/v1") {
            path = path.isEmpty ? "/v1" : "\(path)/v1"
        }
        components.path = path
        components.query = nil
        components.fragment = nil
        return components.url
    }
}

// MARK: - OpenAI API types

private struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable {
        let id: String

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let id = try container.decodeIfPresent(String.self, forKey: .id), !id.isEmpty {
                self.id = id
                return
            }
            if let name = try container.decodeIfPresent(String.self, forKey: .name), !name.isEmpty {
                self.id = name
                return
            }
            throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Missing model id")
        }

        private enum CodingKeys: String, CodingKey {
            case id
            case name
        }
    }

    let data: [Model]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let data = try container.decodeIfPresent([Model].self, forKey: .data) {
            self.data = data
            return
        }
        if let models = try container.decodeIfPresent([Model].self, forKey: .models) {
            self.data = models
            return
        }
        self.data = []
    }

    private enum CodingKeys: String, CodingKey {
        case data
        case models
    }
}

private struct OpenAITool: Encodable {
    let type: String = "function"
    let function: OpenAIFunction

    init(definition: AIToolDefinition) {
        function = OpenAIFunction(definition: definition)
    }
}

private struct OpenAIFunction: Encodable {
    let name: String
    let description: String
    let parameters: OpenAIParameters

    init(definition: AIToolDefinition) {
        name = definition.name
        description = definition.description
        var properties: [String: OpenAIProperty] = [:]
        var required: [String] = []
        for param in definition.parameters {
            properties[param.name] = OpenAIProperty(parameter: param)
            if param.required { required.append(param.name) }
        }
        parameters = OpenAIParameters(properties: properties, required: required)
    }
}

private struct OpenAIParameters: Encodable {
    let type: String = "object"
    let properties: [String: OpenAIProperty]
    let required: [String]
}

private struct OpenAIProperty: Encodable {
    let type: String
    let description: String
    let `enum`: [String]?

    init(parameter: AIToolParameterDefinition) {
        type = parameter.type == "integer" ? "integer" : (parameter.type == "boolean" ? "boolean" : (parameter.type == "number" ? "number" : "string"))
        description = parameter.description
        `enum` = parameter.enumValues
    }
}

private struct OpenAIMessage: Encodable {
    let role: String
    let content: String?
    let tool_calls: [OpenAIToolCall]?
    let tool_call_id: String?
    let name: String?

    init(message: AIMessage) {
        role = message.role.rawValue
        switch message.role {
        case .tool:
            content = message.content
            tool_calls = nil
            tool_call_id = message.toolCallId
            name = message.toolName
        case .assistant:
            content = message.toolCalls.isEmpty ? message.content : (message.content.isEmpty ? nil : message.content)
            tool_calls = message.toolCalls.isEmpty ? nil : message.toolCalls.map { OpenAIToolCall(call: $0) }
            tool_call_id = nil
            name = nil
        default:
            content = message.content
            tool_calls = nil
            tool_call_id = nil
            name = nil
        }
    }
}

private struct OpenAIToolCall: Encodable {
    let id: String
    let type: String = "function"
    let function: OpenAIToolCallFunction

    init(call: AIToolCall) {
        id = call.id
        function = OpenAIToolCallFunction(name: call.name, arguments: call.argumentsJSON)
    }
}

private struct OpenAIToolCallFunction: Encodable {
    let name: String
    let arguments: String
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let stream: Bool
    let tools: [OpenAITool]?
}

private struct OpenAIChatResponse: Decodable {
    struct Choice: Decodable {
        let message: ResponseMessage
    }

    struct ResponseMessage: Decodable {
        let content: String?
        let tool_calls: [ResponseToolCall]?
    }

    struct ResponseToolCall: Decodable {
        struct Function: Decodable {
            let name: String
            let arguments: String
        }

        let id: String
        let function: Function
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
