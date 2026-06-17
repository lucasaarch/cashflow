import XCTest
@testable import CashFlow

@MainActor
final class AIConfigurationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        suiteName = "AIConfigurationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        suiteName = nil
        defaults = nil
        super.tearDown()
    }

    func testOllamaDefaults() {
        let config = AIConfiguration(defaults: defaults)
        XCTAssertEqual(config.ollamaHost, "127.0.0.1")
        XCTAssertEqual(config.ollamaPort, 11434)
    }
}
