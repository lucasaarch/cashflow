import XCTest
@testable import CashFlow

final class OpenAIProviderTests: XCTestCase {
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
        try await secureStoreSave("sk-test-key", for: .openAIAPIKey)

        let provider = await OpenAIProvider(
            configuration: AIConfiguration(),
            client: HTTPClient(session: URLSession(configuration: config))
        )
        let models = try await provider.listModels()
        let modelIDs = await MainActor.run { models.map { $0.id } }

        XCTAssertEqual(modelIDs, ["gpt-4o-mini"])
    }

    private func secureStoreSave(_ value: String, for key: SecureStore.Key) async throws {
        try await Task.detached {
            try SecureStore.save(value, for: key)
        }.value
    }
}
