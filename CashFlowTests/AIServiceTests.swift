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

    func testCompleteWithUnverifiedCustomProviderThrowsNotConfigured() async {
        let suiteName = "AIServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let config = AIConfiguration(defaults: defaults)
        let providerID = UUID()
        config.upsertCustomProvider(
            CustomAIProvider(
                id: providerID,
                name: "Ollama",
                baseURL: "http://127.0.0.1:11434",
                didConnect: false
            )
        )
        config.activeProvider = .custom(providerID)
        config.activeModelID = "llama3"
        let service = AIService(configuration: config)

        do {
            _ = try await service.complete(messages: [AIMessage(role: .user, content: "oi")])
            XCTFail("Expected error")
        } catch let error as AIError {
            XCTAssertEqual(error, .notConfigured(.custom(providerID)))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
