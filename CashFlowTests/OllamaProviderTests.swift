import XCTest
@testable import CashFlow

final class OllamaProviderTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testListModelsParsesTags() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:11434/api/tags")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let json = #"{"models":[{"name":"llama3.2","model":"llama3.2:latest"}]}"#
            return (response, Data(json.utf8))
        }
        let defaults = UserDefaults(suiteName: "OllamaProviderTests")!
        defaults.set("127.0.0.1", forKey: UserDefaultsKeys.aiOllamaHost)
        defaults.set(11434, forKey: UserDefaultsKeys.aiOllamaPort)
        let aiConfig = AIConfiguration(defaults: defaults)
        let provider = OllamaProvider(
            configuration: aiConfig,
            client: HTTPClient(session: URLSession(configuration: config))
        )
        let models = try await provider.listModels()
        XCTAssertEqual(models.first?.id, "llama3.2:latest")
    }

    func testSupportsToolCallsByDefault() {
        let provider = OllamaProvider(configuration: AIConfiguration())
        XCTAssertTrue(provider.supportsToolCalls)
    }

    func testCompleteParsesToolCalls() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:11434/api/chat")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let json = """
            {
              "model": "qwen2.5:latest",
              "message": {
                "role": "assistant",
                "content": "",
                "tool_calls": [
                  {
                    "function": {
                      "name": "get_month_summary",
                      "arguments": { "reference_date": "2026-06-17" }
                    }
                  }
                ]
              },
              "done": true
            }
            """
            return (response, Data(json.utf8))
        }

        let defaults = UserDefaults(suiteName: "OllamaProviderTests.tools")!
        defaults.set("127.0.0.1", forKey: UserDefaultsKeys.aiOllamaHost)
        defaults.set(11434, forKey: UserDefaultsKeys.aiOllamaPort)
        let aiConfig = AIConfiguration(defaults: defaults)
        let provider = OllamaProvider(
            configuration: aiConfig,
            client: HTTPClient(session: URLSession(configuration: config))
        )

        let response = try await provider.complete(
            AICompletionRequest(
                modelID: "qwen2.5:latest",
                messages: [AIMessage(role: .user, content: "Como está meu mês?")],
                tools: [AIToolDefinition(name: "get_month_summary", description: "Resumo do mês")]
            )
        )

        XCTAssertTrue(response.hasToolCalls)
        XCTAssertEqual(response.toolCalls.first?.name, "get_month_summary")
        XCTAssertTrue(response.toolCalls.first?.argumentsJSON.contains("2026-06-17") == true)
    }
}
