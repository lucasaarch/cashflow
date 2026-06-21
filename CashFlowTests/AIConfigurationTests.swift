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
        defaults.set("unknown-provider", forKey: UserDefaultsKeys.aiActiveProvider)
        let config = AIConfiguration(defaults: defaults)

        XCTAssertNil(config.activeProvider)
        XCTAssertNil(defaults.string(forKey: UserDefaultsKeys.aiActiveProvider))
    }

    func testActiveProviderMigratesLegacyLocalProvider() {
        defaults.set("local", forKey: UserDefaultsKeys.aiActiveProvider)
        defaults.set(OpenAIBaseURLNormalizer.defaultCompatibleURL, forKey: UserDefaultsKeys.aiOpenAICompatibleBaseURL)
        defaults.set(true, forKey: UserDefaultsKeys.aiOpenAICompatibleDidConnect)

        let config = AIConfiguration(defaults: defaults)
        guard case .custom = config.activeProvider else {
            return XCTFail("Expected migrated custom provider")
        }

        XCTAssertEqual(config.customProviders.count, 1)
        XCTAssertEqual(config.customProviders.first?.baseURL, OpenAIBaseURLNormalizer.defaultCompatibleURL)
        XCTAssertTrue(config.customProviders.first?.isConfigured == true)
    }

    func testCustomProviderIsNotConfiguredByDefault() {
        let config = AIConfiguration(defaults: defaults)
        let provider = CustomAIProvider(name: "Ollama", baseURL: "127.0.0.1:11434")
        config.upsertCustomProvider(provider)

        XCTAssertFalse(config.isConfigured(.custom(provider.id)))
    }

    func testCustomProviderRequiresSuccessfulConnection() {
        let config = AIConfiguration(defaults: defaults)
        let provider = CustomAIProvider(name: "Ollama", baseURL: "127.0.0.1:11434")
        config.upsertCustomProvider(provider)

        XCTAssertEqual(
            config.customProvider(id: provider.id)?.resolvedBaseURL?.absoluteString,
            "http://127.0.0.1:11434/v1"
        )
        XCTAssertFalse(config.isConfigured(.custom(provider.id)))

        config.markCustomProviderConnected(id: provider.id)
        XCTAssertTrue(config.isConfigured(.custom(provider.id)))
    }

    func testCustomProviderClearsConnectionWhenURLChanges() {
        let config = AIConfiguration(defaults: defaults)
        var provider = CustomAIProvider(name: "Ollama", baseURL: "127.0.0.1:11434", didConnect: true)
        config.upsertCustomProvider(provider)
        XCTAssertTrue(config.isConfigured(.custom(provider.id)))

        provider.baseURL = "127.0.0.1:1234"
        config.upsertCustomProvider(provider)
        XCTAssertFalse(config.isConfigured(.custom(provider.id)))
    }

    func testConfiguredProvidersIncludesCustomProvider() {
        let config = AIConfiguration(defaults: defaults)
        let custom = CustomAIProvider(name: "LM Studio", baseURL: "http://127.0.0.1:1234/v1", didConnect: true)
        config.upsertCustomProvider(custom)

        XCTAssertTrue(config.configuredProviders().contains(.custom(custom.id)))
    }
}
