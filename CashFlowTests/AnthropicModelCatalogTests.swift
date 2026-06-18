import XCTest
@testable import CashFlow

final class AnthropicModelCatalogTests: XCTestCase {
    func testMigratesRetiredSonnet4() {
        XCTAssertEqual(
            AnthropicModelCatalog.migrate(modelID: "claude-sonnet-4-20250514"),
            "claude-sonnet-4-6"
        )
    }

    func testMigratesRetiredHaiku35() {
        XCTAssertEqual(
            AnthropicModelCatalog.migrate(modelID: "claude-3-5-haiku-20241022"),
            "claude-haiku-4-5"
        )
    }

    func testKeepsCurrentModelIDs() {
        XCTAssertEqual(
            AnthropicModelCatalog.migrate(modelID: "claude-sonnet-4-6"),
            "claude-sonnet-4-6"
        )
    }
}
