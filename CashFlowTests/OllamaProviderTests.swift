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
}
