import XCTest
@testable import CashFlow

final class AnthropicProviderTests: XCTestCase {
    override class func setUp() {
        SecureStoreTestIsolation.activate()
    }

    override class func tearDown() {
        SecureStoreTestIsolation.deactivate()
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testListModelsFetchesFromAPI() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let json = """
            {
              "data": [
                {
                  "id": "claude-sonnet-4-6",
                  "display_name": "Claude Sonnet 4.6",
                  "max_input_tokens": 1000000,
                  "type": "model"
                },
                {
                  "id": "claude-sonnet-4-20250514",
                  "display_name": "Claude Sonnet 4",
                  "max_input_tokens": 200000,
                  "type": "model"
                }
              ],
              "has_more": false
            }
            """
            return (response, Data(json.utf8))
        }

        let defaults = UserDefaults(suiteName: "AnthropicProviderTests")!
        try await secureStoreSave("sk-ant-test", for: .anthropicAPIKey)

        let provider = await AnthropicProvider(
            configuration: AIConfiguration(defaults: defaults),
            client: HTTPClient(session: URLSession(configuration: config))
        )

        let models = try await provider.listModels()
        let values = await MainActor.run {
            (
                count: models.count,
                id: models.first?.id,
                displayName: models.first?.displayName,
                contextWindow: models.first?.contextWindow
            )
        }

        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.id, "claude-sonnet-4-6")
        XCTAssertEqual(values.displayName, "Claude Sonnet 4.6")
        XCTAssertEqual(values.contextWindow, 1_000_000)
    }

    private func secureStoreSave(_ value: String, for key: SecureStore.Key) async throws {
        try await Task.detached {
            try SecureStore.save(value, for: key)
        }.value
    }
}
