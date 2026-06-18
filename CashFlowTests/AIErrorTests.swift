import XCTest
@testable import CashFlow

final class AIErrorTests: XCTestCase {
    func testNoActiveProviderDescription() {
        let error = AIError.noActiveProvider
        XCTAssertEqual(error.errorDescription, "Nenhum provedor de IA está ativo. Configure em Inteligência.")
    }
}
