import Foundation
import os

enum AnthropicModelCatalog {
    /// Used only when the Models API is unreachable.
    static let fallbackModels: [AIModel] = [
        AIModel(id: "claude-sonnet-4-6", displayName: "Claude Sonnet 4.6", contextWindow: 1_000_000),
        AIModel(id: "claude-haiku-4-5", displayName: "Claude Haiku 4.5", contextWindow: 200_000),
        AIModel(id: "claude-opus-4-8", displayName: "Claude Opus 4.8", contextWindow: 1_000_000)
    ]

    private static let retiredReplacements: [String: String] = [
        "claude-sonnet-4-20250514": "claude-sonnet-4-6",
        "claude-sonnet-4-0": "claude-sonnet-4-6",
        "claude-sonnet-4-5-20250929": "claude-sonnet-4-6",
        "claude-3-5-sonnet-20241022": "claude-sonnet-4-6",
        "claude-3-5-sonnet-20240620": "claude-sonnet-4-6",
        "claude-3-7-sonnet-20250219": "claude-sonnet-4-6",
        "claude-3-5-haiku-20241022": "claude-haiku-4-5",
        "claude-opus-4-20250514": "claude-opus-4-8",
        "claude-opus-4-0": "claude-opus-4-8"
    ]

    static func migrate(modelID: String) -> String {
        retiredReplacements[modelID] ?? modelID
    }

    static func isRetired(modelID: String) -> Bool {
        retiredReplacements.keys.contains(modelID)
    }
}

struct AnthropicProvider: AIProvider {
    let id: AIProviderID = .anthropic
    private let configuration: AIConfiguration
    private let client: HTTPClient

    private let baseURL = URL(string: "https://api.anthropic.com/v1")!
    private let apiVersion = "2023-06-01"

    init(configuration: AIConfiguration, client: HTTPClient = HTTPClient()) {
        self.configuration = configuration
        self.client = client
    }

    func validateConfiguration() async throws {
        guard apiKey != nil else { throw AIError.notConfigured(.anthropic) }
        _ = try await listModels()
    }

    func listModels() async throws -> [AIModel] {
        guard let apiKey else { throw AIError.notConfigured(.anthropic) }
        let models = try await fetchModels(apiKey: apiKey)
        return models.isEmpty ? AnthropicModelCatalog.fallbackModels : models
    }

    private func fetchModels(apiKey: String) async throws -> [AIModel] {
        var results: [AIModel] = []
        var afterID: String?

        repeat {
            var url = baseURL.appendingPathComponent("models")
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            var queryItems = [URLQueryItem(name: "limit", value: "100")]
            if let afterID {
                queryItems.append(URLQueryItem(name: "after_id", value: afterID))
            }
            components.queryItems = queryItems
            url = components.url!

            let page: AnthropicModelsListResponse = try await client.get(
                AnthropicModelsListResponse.self,
                url: url,
                headers: authHeaders(apiKey)
            )

            let pageModels = page.data
                .filter { $0.type == "model" && $0.id.hasPrefix("claude-") }
                .filter { !AnthropicModelCatalog.isRetired(modelID: $0.id) }
                .map { item in
                    AIModel(
                        id: item.id,
                        displayName: item.display_name,
                        contextWindow: item.max_input_tokens > 0 ? item.max_input_tokens : nil
                    )
                }
            results.append(contentsOf: pageModels)

            if page.has_more == true, let lastID = page.last_id {
                afterID = lastID
            } else {
                afterID = nil
            }
        } while afterID != nil

        return results
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        guard let apiKey else { throw AIError.notConfigured(.anthropic) }
        let system = request.messages.first(where: { $0.role == .system })?.content
        let messages = try AnthropicMessageEncoder.encode(request.messages.filter { $0.role != .system })
        let body = AnthropicRequest(
            model: request.modelID,
            max_tokens: request.maxTokens ?? (request.tools.isEmpty ? 1024 : 4096),
            system: system,
            messages: messages,
            temperature: request.temperature,
            stream: false,
            tools: request.tools.isEmpty ? nil : request.tools.map { AnthropicTool(definition: $0) }
        )
        AILogger.provider.debug("Anthropic complete model=\(request.modelID, privacy: .public) messages=\(messages.count) tools=\(request.tools.count)")
        let response: AnthropicResponse = try await client.postJSON(
            AnthropicResponse.self,
            url: baseURL.appendingPathComponent("messages"),
            body: body,
            headers: authHeaders(apiKey)
        )

        var textParts: [String] = []
        var toolCalls: [AIToolCall] = []
        for block in response.content {
            switch block.type {
            case "text":
                if let text = block.text { textParts.append(text) }
            case "tool_use":
                if let id = block.id, let name = block.name {
                    let plainInput: [String: Any] = (block.input ?? [:]).mapValues(\.value)
                    let argsString: String
                    if JSONSerialization.isValidJSONObject(plainInput),
                       let data = try? JSONSerialization.data(withJSONObject: plainInput),
                       let string = String(data: data, encoding: .utf8) {
                        argsString = string
                    } else {
                        argsString = "{}"
                    }
                    toolCalls.append(AIToolCall(id: id, name: name, argumentsJSON: argsString))
                }
            default:
                break
            }
        }

        AILogger.provider.debug("Anthropic complete returned toolCalls=\(toolCalls.count) textBlocks=\(textParts.count)")
        if !toolCalls.isEmpty {
            return AICompletionResponse(
                content: textParts.joined(),
                toolCalls: toolCalls,
                finishReason: .toolCalls
            )
        }

        let text = textParts.joined()
        guard !text.isEmpty else {
            AILogger.provider.error("Anthropic returned no content and no tool calls")
            throw AIError.decodingFailed
        }
        return AICompletionResponse(content: text)
    }

    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey else { throw AIError.notConfigured(.anthropic) }
                    let system = request.messages.first(where: { $0.role == .system })?.content
                    let messages = try AnthropicMessageEncoder.encode(request.messages.filter { $0.role != .system })
                    let body = AnthropicRequest(
                        model: request.modelID,
                        max_tokens: request.maxTokens ?? (request.tools.isEmpty ? 1024 : 4096),
                        system: system,
                        messages: messages,
                        temperature: request.temperature,
                        stream: true,
                        tools: nil
                    )
                    let data = try JSONEncoder().encode(body)
                    let stream = client.postStream(
                        url: baseURL.appendingPathComponent("messages"),
                        body: data,
                        headers: authHeaders(apiKey)
                    )
                    for try await line in stream {
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard let chunkData = json.data(using: .utf8) else { continue }
                        let event = try JSONDecoder().decode(AnthropicStreamEvent.self, from: chunkData)
                        if event.type == "content_block_delta", let text = event.delta?.text, !text.isEmpty {
                            continuation.yield(AIStreamChunk(content: text, isFinished: false))
                        }
                        if event.type == "message_stop" {
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

    private var apiKey: String? { SecureStore.read(.anthropicAPIKey) }

    private func authHeaders(_ apiKey: String) -> [String: String] {
        [
            "x-api-key": apiKey,
            "anthropic-version": apiVersion
        ]
    }
}

// MARK: - Anthropic encoding

private enum AnthropicMessageEncoder {
    static func encode(_ messages: [AIMessage]) throws -> [AnthropicMessage] {
        var result: [AnthropicMessage] = []
        var index = 0
        while index < messages.count {
            let message = messages[index]
            switch message.role {
            case .user:
                result.append(AnthropicMessage(role: "user", content: .text(message.content)))
                index += 1
            case .assistant:
                if !message.toolCalls.isEmpty {
                    var blocks: [AnthropicContentBlock] = []
                    if !message.content.isEmpty {
                        blocks.append(.text(message.content))
                    }
                    for call in message.toolCalls {
                        let input = try jsonObject(from: call.argumentsJSON)
                        blocks.append(.toolUse(id: call.id, name: call.name, input: input))
                    }
                    result.append(AnthropicMessage(role: "assistant", content: .blocks(blocks)))
                } else {
                    result.append(AnthropicMessage(role: "assistant", content: .text(message.content)))
                }
                index += 1
            case .tool:
                var toolResults: [AnthropicContentBlock] = []
                while index < messages.count, messages[index].role == .tool {
                    let toolMessage = messages[index]
                    if let callID = toolMessage.toolCallId {
                        toolResults.append(.toolResult(id: callID, content: toolMessage.content))
                    }
                    index += 1
                }
                result.append(AnthropicMessage(role: "user", content: .blocks(toolResults)))
            case .system:
                index += 1
            }
        }
        return result
    }

    private static func jsonObject(from json: String) throws -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        return object
    }
}

private enum AnthropicContentPayload: Encodable {
    case text(String)
    case blocks([AnthropicContentBlock])

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .blocks(let blocks):
            try container.encode(blocks)
        }
    }
}

private enum AnthropicContentBlock: Encodable {
    case text(String)
    case toolUse(id: String, name: String, input: [String: Any])
    case toolResult(id: String, content: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .toolUse(let id, let name, let input):
            try container.encode("tool_use", forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(AnyEncodable(input), forKey: .input)
        case .toolResult(let id, let content):
            try container.encode("tool_result", forKey: .type)
            try container.encode(id, forKey: .tool_use_id)
            try container.encode(content, forKey: .content)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, text, id, name, input, tool_use_id, content
    }
}

private struct AnyEncodable: Encodable {
    let value: Any
    init(_ value: Any) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let dict = value as? [String: Any] {
            try container.encode(dict.mapValues { AnyEncodable($0) })
        } else if let array = value as? [Any] {
            try container.encode(array.map { AnyEncodable($0) })
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else {
            try container.encode(String(describing: value))
        }
    }
}

private struct AnthropicMessage: Encodable {
    let role: String
    let content: AnthropicContentPayload
}

private struct AnthropicTool: Encodable {
    let name: String
    let description: String
    let input_schema: AnthropicInputSchema

    init(definition: AIToolDefinition) {
        name = definition.name
        description = definition.description
        var properties: [String: AnthropicProperty] = [:]
        var required: [String] = []
        for param in definition.parameters {
            properties[param.name] = AnthropicProperty(parameter: param)
            if param.required { required.append(param.name) }
        }
        input_schema = AnthropicInputSchema(properties: properties, required: required)
    }
}

private struct AnthropicInputSchema: Encodable {
    let type: String = "object"
    let properties: [String: AnthropicProperty]
    let required: [String]
}

private struct AnthropicProperty: Encodable {
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

private struct AnthropicRequest: Encodable {
    let model: String
    let max_tokens: Int
    let system: String?
    let messages: [AnthropicMessage]
    let temperature: Double
    let stream: Bool
    let tools: [AnthropicTool]?
}

private struct AnthropicResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
        let id: String?
        let name: String?
        let input: [String: AnyDecodable]?

        enum CodingKeys: String, CodingKey {
            case type, text, id, name, input
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            text = try container.decodeIfPresent(String.self, forKey: .text)
            id = try container.decodeIfPresent(String.self, forKey: .id)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            if let raw = try container.decodeIfPresent([String: AnyDecodable].self, forKey: .input) {
                input = raw
            } else {
                input = nil
            }
        }
    }

    let content: [Block]
}

private struct AnyDecodable: Decodable {
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
        } else if let dict = try? container.decode([String: AnyDecodable].self) {
            value = dict.mapValues(\.value)
        } else if let array = try? container.decode([AnyDecodable].self) {
            value = array.map(\.value)
        } else {
            value = ""
        }
    }
}

private struct AnthropicModelsListResponse: Decodable {
    struct ModelInfo: Decodable {
        let id: String
        let display_name: String
        let max_input_tokens: Int
        let type: String
    }

    let data: [ModelInfo]
    let has_more: Bool?
    let last_id: String?
}

private struct AnthropicStreamEvent: Decodable {
    struct Delta: Decodable { let text: String? }
    let type: String
    let delta: Delta?
}
