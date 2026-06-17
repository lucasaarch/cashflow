import XCTest
@testable import CashFlow

@MainActor
final class AIServiceTests: XCTestCase {
    func testCompleteWithoutProviderThrows() async {
        let suiteName = "AIServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let config = AIConfiguration(defaults: defaults)
        config.activeProvider = nil
        let service = AIService(configuration: config)

        do {
            _ = try await service.complete(messages: [AIMessage(role: .user, content: "oi")])
            XCTFail("Expected error")
        } catch let error as AIError {
            XCTAssertEqual(error, .noActiveProvider)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
