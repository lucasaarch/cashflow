import Foundation
import os

struct OllamaProvider: AIProvider {
    let id: AIProviderID = .ollama
    var supportsToolCalls: Bool { true }
    private let configuration: AIConfiguration
    private let client: HTTPClient

    /// Local models (especially smaller quants used with tool calls) can take well over
    /// 30s just to produce a structured response. Use a generous chat timeout.
    private let chatTimeout: TimeInterval = 180

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
            messages: request.messages.map { OllamaMessage(message: $0) },
            stream: false,
            tools: request.tools.isEmpty ? nil : request.tools.map { OllamaTool(definition: $0) }
        )
        AILogger.provider.debug("Ollama complete model=\(request.modelID, privacy: .public) messages=\(request.messages.count) tools=\(request.tools.count)")
        let response: OllamaChatResponse = try await client.postJSON(
            OllamaChatResponse.self,
            url: baseURL.appendingPathComponent("api/chat"),
            body: body,
            timeout: chatTimeout
        )

        let message = response.message
        let toolCalls = OllamaToolCallParser.parse(message.tool_calls)
        AILogger.provider.debug("Ollama complete model=\(request.modelID, privacy: .public) toolCalls=\(toolCalls.count) contentChars=\(message.content?.count ?? 0)")
        if !toolCalls.isEmpty {
            return AICompletionResponse(
                content: message.content ?? "",
                toolCalls: toolCalls,
                finishReason: .toolCalls
            )
        }

        guard let content = message.content, !content.isEmpty else {
            AILogger.provider.error("Ollama returned empty content with no tool calls")
            throw AIError.decodingFailed
        }
        return AICompletionResponse(content: content)
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
                        messages: request.messages.map { OllamaMessage(message: $0) },
                        stream: true,
                        tools: nil
                    )
                    let data = try JSONEncoder().encode(body)
                    let stream = client.postStream(
                        url: baseURL.appendingPathComponent("api/chat"),
                        body: data,
                        timeout: chatTimeout
                    )
                    for try await line in stream {
                        guard let chunkData = line.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(OllamaChatResponse.self, from: chunkData)
                        let content = chunk.message.content ?? ""
                        if !content.isEmpty {
                            continuation.yield(AIStreamChunk(content: content, isFinished: false))
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

// MARK: - Tool call parsing

private enum OllamaToolCallParser {
    static func parse(_ raw: [OllamaResponseToolCall]?) -> [AIToolCall] {
        guard let raw, !raw.isEmpty else { return [] }
        return raw.enumerated().map { index, call in
            let name = call.function.name
            let id = call.id ?? "ollama-\(index)-\(name)"
            let argumentsJSON = serializeArguments(call.function.arguments)
            return AIToolCall(id: id, name: name, argumentsJSON: argumentsJSON)
        }
    }

    private static func serializeArguments(_ value: OllamaJSONValue?) -> String {
        guard let value else { return "{}" }
        if case .object(let dict) = value {
            guard let data = try? JSONSerialization.data(withJSONObject: dict),
                  let string = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return string
        }
        if case .string(let string) = value, !string.isEmpty {
            return string
        }
        return "{}"
    }
}

// MARK: - Ollama API types

private struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
        let model: String
    }

    let models: [Model]
}

private struct OllamaTool: Encodable {
    let type: String = "function"
    let function: OllamaFunctionSchema

    init(definition: AIToolDefinition) {
        function = OllamaFunctionSchema(definition: definition)
    }
}

private struct OllamaFunctionSchema: Encodable {
    let name: String
    let description: String
    let parameters: OllamaParametersSchema

    init(definition: AIToolDefinition) {
        name = definition.name
        description = definition.description
        var properties: [String: OllamaPropertySchema] = [:]
        var required: [String] = []
        for param in definition.parameters {
            properties[param.name] = OllamaPropertySchema(parameter: param)
            if param.required { required.append(param.name) }
        }
        parameters = OllamaParametersSchema(properties: properties, required: required)
    }
}

private struct OllamaParametersSchema: Encodable {
    let type: String = "object"
    let properties: [String: OllamaPropertySchema]
    let required: [String]
}

private struct OllamaPropertySchema: Encodable {
    let type: String
    let description: String
    let `enum`: [String]?

    init(parameter: AIToolParameterDefinition) {
        switch parameter.type {
        case "integer": type = "integer"
        case "boolean": type = "boolean"
        case "number": type = "number"
        default: type = "string"
        }
        description = parameter.description
        `enum` = parameter.enumValues
    }
}

private struct OllamaMessage: Encodable {
    let role: String
    let content: String?
    let tool_calls: [OllamaOutgoingToolCall]?
    let tool_name: String?

    init(message: AIMessage) {
        role = message.role.rawValue
        switch message.role {
        case .tool:
            content = message.content
            tool_calls = nil
            tool_name = message.toolName
        case .assistant:
            content = message.toolCalls.isEmpty ? message.content : (message.content.isEmpty ? nil : message.content)
            tool_calls = message.toolCalls.isEmpty ? nil : message.toolCalls.enumerated().map { index, call in
                OllamaOutgoingToolCall(call: call, index: index)
            }
            tool_name = nil
        default:
            content = message.content
            tool_calls = nil
            tool_name = nil
        }
    }
}

private struct OllamaOutgoingToolCall: Encodable {
    let type: String = "function"
    let function: OllamaOutgoingFunction

    init(call: AIToolCall, index: Int) {
        function = OllamaOutgoingFunction(call: call, index: index)
    }
}

private struct OllamaOutgoingFunction: Encodable {
    let index: Int
    let name: String
    let arguments: AnyEncodableValue

    init(call: AIToolCall, index: Int) {
        self.index = index
        self.name = call.name
        self.arguments = AnyEncodableValue(OllamaJSONCodec.decodeObject(call.argumentsJSON))
    }
}

private struct OllamaChatRequest: Encodable {
    let model: String
    let messages: [OllamaMessage]
    let stream: Bool
    let tools: [OllamaTool]?
}

private struct OllamaChatResponse: Decodable {
    struct Message: Decodable {
        let role: String?
        let content: String?
        let tool_calls: [OllamaResponseToolCall]?
    }

    let message: Message
    let done: Bool?

    var isFinished: Bool { done ?? false }
}

private struct OllamaResponseToolCall: Decodable {
    let id: String?
    let function: OllamaResponseFunction
}

private struct OllamaResponseFunction: Decodable {
    let name: String
    let arguments: OllamaJSONValue?
}

private enum OllamaJSONValue: Decodable {
    case object([String: Any])
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }
        if let dict = try? container.decode([String: OllamaAnyDecodable].self) {
            self = .object(dict.mapValues(\.value))
            return
        }
        self = .object([:])
    }
}

private struct OllamaAnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let dict = try? container.decode([String: OllamaAnyDecodable].self) {
            value = dict.mapValues(\.value)
        } else if let array = try? container.decode([OllamaAnyDecodable].self) {
            value = array.map(\.value)
        } else {
            value = ""
        }
    }
}

private enum OllamaJSONCodec {
    static func decodeObject(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }
}

private struct AnyEncodableValue: Encodable {
    let value: Any

    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyEncodableValue($0) })
        case let array as [Any]:
            try container.encode(array.map { AnyEncodableValue($0) })
        case let string as String:
            try container.encode(string)
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        default:
            try container.encode(String(describing: value))
        }
    }
}
