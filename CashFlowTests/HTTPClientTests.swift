import XCTest
@testable import CashFlow

@MainActor
final class HTTPClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func testGETDecodesJSON() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("{\"ok\":true}".utf8))
        }
        let client = HTTPClient(session: URLSession(configuration: config))
        struct Payload: Decodable { let ok: Bool }
        let result: Payload = try await client.get(
            Payload.self,
            url: URL(string: "http://test.local/tags")!
        )
        XCTAssertTrue(result.ok)
    }
}
