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

    func testActiveProviderIgnoresLegacyUnsupportedProviderValues() {
        defaults.set("local", forKey: UserDefaultsKeys.aiActiveProvider)
        let config = AIConfiguration(defaults: defaults)

        XCTAssertNil(config.activeProvider)
        XCTAssertNil(defaults.string(forKey: UserDefaultsKeys.aiActiveProvider))
    }
}
