import XCTest
@testable import CashFlow

final class OpenAIProviderTests: XCTestCase {
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
        try SecureStore.save("sk-test-key", for: .openAIAPIKey)
        defer { SecureStore.delete(.openAIAPIKey) }

        let provider = OpenAIProvider(
            configuration: AIConfiguration(),
            client: HTTPClient(session: URLSession(configuration: config))
        )
        let models = try await provider.listModels()
        XCTAssertEqual(models.map(\.id), ["gpt-4o-mini"])
    }
}
