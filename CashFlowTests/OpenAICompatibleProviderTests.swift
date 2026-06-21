import XCTest
@testable import CashFlow

@MainActor
final class OpenAICompatibleProviderTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override class func setUp() {
        SecureStoreTestIsolation.activate()
    }

    override class func tearDown() {
        SecureStoreTestIsolation.deactivate()
    }

    override func setUp() {
        suiteName = "OpenAICompatibleProviderTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        MockURLProtocol.handler = nil
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        suiteName = nil
        defaults = nil
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testListModelsReturnsAllModels() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:11434/v1/models")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let json = #"{"data":[{"id":"llama3.2:latest"},{"id":"qwen2.5:7b"}]}"#
            return (response, Data(json.utf8))
        }

        let customProvider = CustomAIProvider(
            name: "Ollama",
            baseURL: "http://127.0.0.1:11434/v1"
        )
        let provider = OpenAICompatibleProvider(
            customProvider: customProvider,
            client: HTTPClient(session: URLSession(configuration: config))
        )
        let models = try await provider.listModels()
        let modelIDs = models.map(\.id)

        XCTAssertEqual(modelIDs, ["llama3.2:latest", "qwen2.5:7b"])
    }

    func testWorksWithoutAPIKey() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let response = HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:11434/v1/models")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let json = #"{"data":[{"id":"llama3.2:latest"}]}"#
            return (response, Data(json.utf8))
        }

        let customProvider = CustomAIProvider(
            name: "Ollama",
            baseURL: "http://127.0.0.1:11434/v1"
        )
        let provider = OpenAICompatibleProvider(
            customProvider: customProvider,
            client: HTTPClient(session: URLSession(configuration: config))
        )
        let models = try await provider.listModels()

        XCTAssertEqual(models.count, 1)
    }

    func testListModelsSupportsOllamaModelsEnvelope() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:11434/v1/models")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let json = #"{"models":[{"name":"llama3.2:latest"}]}"#
            return (response, Data(json.utf8))
        }

        let customProvider = CustomAIProvider(
            name: "Ollama",
            baseURL: "http://127.0.0.1:11434/v1"
        )
        let provider = OpenAICompatibleProvider(
            customProvider: customProvider,
            client: HTTPClient(session: URLSession(configuration: config))
        )
        let models = try await provider.listModels()

        XCTAssertEqual(models.map(\.id), ["llama3.2:latest"])
    }
}
