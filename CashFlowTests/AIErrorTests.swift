import XCTest
@testable import CashFlow

final class AIErrorTests: XCTestCase {
    func testNoActiveProviderDescription() {
        let error = AIError.noActiveProvider
        XCTAssertEqual(error.errorDescription, "Nenhum provedor de IA está ativo. Configure em Inteligência.")
    }

    func testOllamaUnreachableDescription() {
        let error = AIError.networkUnavailable(host: "127.0.0.1", port: 11434)
        XCTAssertTrue(error.errorDescription?.contains("11434") == true)
    }
}
