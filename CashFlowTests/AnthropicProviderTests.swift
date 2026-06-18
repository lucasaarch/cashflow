import XCTest
@testable import CashFlow

final class AnthropicProviderTests: XCTestCase {
    private var savedAnthropicKey: String?

    override func setUp() {
        savedAnthropicKey = SecureStore.read(.anthropicAPIKey)
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        restoreAnthropicKeyIfSaved()
        super.tearDown()
    }

    /// Restores a key the user had before the test. Never deletes — that would wipe real credentials.
    private func restoreAnthropicKeyIfSaved() {
        guard let savedAnthropicKey else { return }
        try? SecureStore.save(savedAnthropicKey, for: .anthropicAPIKey)
    }

    /// Cleans up after a test that wrote a temporary key.
    private func cleanupAnthropicKeyAfterTest() {
        if let savedAnthropicKey {
            try? SecureStore.save(savedAnthropicKey, for: .anthropicAPIKey)
        } else {
            SecureStore.delete(.anthropicAPIKey)
        }
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
        defaults.set("127.0.0.1", forKey: UserDefaultsKeys.aiOllamaHost)
        try SecureStore.save("sk-ant-test", for: .anthropicAPIKey)
        defer { cleanupAnthropicKeyAfterTest() }

        let provider = AnthropicProvider(
            configuration: AIConfiguration(defaults: defaults),
            client: HTTPClient(session: URLSession(configuration: config))
        )

        let models = try await provider.listModels()
        XCTAssertEqual(models.count, 1)
        XCTAssertEqual(models.first?.id, "claude-sonnet-4-6")
        XCTAssertEqual(models.first?.displayName, "Claude Sonnet 4.6")
        XCTAssertEqual(models.first?.contextWindow, 1_000_000)
    }
}
