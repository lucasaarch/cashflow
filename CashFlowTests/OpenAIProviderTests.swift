import XCTest
@testable import CashFlow

final class OpenAIProviderTests: XCTestCase {
    private var savedOpenAIKey: String?

    override func setUp() {
        savedOpenAIKey = SecureStore.read(.openAIAPIKey)
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        restoreOpenAIKeyIfSaved()
        super.tearDown()
    }

    /// Restores a key the user had before the test. Never deletes — that would wipe real credentials.
    private func restoreOpenAIKeyIfSaved() {
        guard let savedOpenAIKey else { return }
        try? SecureStore.save(savedOpenAIKey, for: .openAIAPIKey)
    }

    /// Cleans up after a test that wrote a temporary key.
    private func cleanupOpenAIKeyAfterTest() {
        if let savedOpenAIKey {
            try? SecureStore.save(savedOpenAIKey, for: .openAIAPIKey)
        } else {
            SecureStore.delete(.openAIAPIKey)
        }
    }

    func testListModelsFiltersChatModels() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.openai.com/v1/models")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let json = #"{"data":[{"id":"gpt-4o-mini"},{"id":"dall-e-3"}]}"#
            return (response, Data(json.utf8))
        }
        try SecureStore.save("sk-test-key", for: .openAIAPIKey)
        defer { cleanupOpenAIKeyAfterTest() }

        let provider = OpenAIProvider(
            configuration: AIConfiguration(),
            client: HTTPClient(session: URLSession(configuration: config))
        )
        let models = try await provider.listModels()
        XCTAssertEqual(models.map(\.id), ["gpt-4o-mini"])
    }
}
