import Foundation

struct OpenAIProvider: AIProvider {
    let id: AIProviderID = .openai
    private let configuration: AIConfiguration
    private let client: HTTPClient

    private let baseURL = URL(string: "https://api.openai.com/v1")!

    init(configuration: AIConfiguration, client: HTTPClient = HTTPClient()) {
        self.configuration = configuration
        self.client = client
    }

    func validateConfiguration() async throws {
        guard apiKey != nil else { throw AIError.notConfigured(.openai) }
        _ = try await listModels()
    }

    func listModels() async throws -> [AIModel] {
        guard let apiKey else { throw AIError.notConfigured(.openai) }
        let response: OpenAIModelsResponse = try await client.get(
            OpenAIModelsResponse.self,
            url: baseURL.appendingPathComponent("models"),
            headers: authHeaders(apiKey)
        )
        return response.data
            .map(\.id)
            .filter { $0.contains("gpt") || $0.hasPrefix("o") }
            .sorted()
            .map { AIModel(id: $0, displayName: $0, contextWindow: nil) }
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        guard let apiKey else { throw AIError.notConfigured(.openai) }
        let body = OpenAIChatRequest(
            model: request.modelID,
            messages: request.messages.map { OpenAIMessage(message: $0) },
            temperature: request.temperature,
            stream: false,
            tools: request.tools.isEmpty ? nil : request.tools.map { OpenAITool(definition: $0) }
        )
        let response: OpenAIChatResponse = try await client.postJSON(
            OpenAIChatResponse.self,
            url: baseURL.appendingPathComponent("chat/completions"),
            body: body,
            headers: authHeaders(apiKey)
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
    }

    func stream(_ request: AICompletionRequest) -> AsyncThrowingStream<AIStreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let apiKey else { throw AIError.notConfigured(.openai) }
                    let body = OpenAIChatRequest(
                        model: request.modelID,
                        messages: request.messages.map { OpenAIMessage(message: $0) },
                        temperature: request.temperature,
                        stream: true,
                        tools: nil
                    )
                    let data = try JSONEncoder().encode(body)
                    let stream = client.postStream(
                        url: baseURL.appendingPathComponent("chat/completions"),
                        body: data,
                        headers: authHeaders(apiKey)
                    )
                    for try await line in stream {
                        guard line.hasPrefix("data: "), line != "data: [DONE]" else { continue }
                        let json = String(line.dropFirst(6))
                        guard let chunkData = json.data(using: .utf8) else { continue }
                        let chunk = try JSONDecoder().decode(OpenAIStreamResponse.self, from: chunkData)
                        if let content = chunk.choices.first?.delta.content, !content.isEmpty {
                            continuation.yield(AIStreamChunk(content: content, isFinished: false))
                        }
                    }
                    continuation.yield(AIStreamChunk(content: "", isFinished: true))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private var apiKey: String? { SecureStore.read(.openAIAPIKey) }

    private func authHeaders(_ apiKey: String) -> [String: String] {
        ["Authorization": "Bearer \(apiKey)"]
    }
}

// MARK: - OpenAI API types

private struct OpenAIModelsResponse: Decodable {
    struct Model: Decodable { let id: String }
    let data: [Model]
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
