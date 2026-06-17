import XCTest
@testable import CashFlow

final class AICategorizeServiceTests: XCTestCase {
    func testParsesCategorySuggestionJSON() throws {
        let json = #"{"categoryId":"ABC","confidence":0.91}"#
        let result = try AICategorizeParsing.parseCategorySuggestion(json)
        XCTAssertEqual(result.categoryId, "ABC")
        XCTAssertEqual(result.confidence, 0.91, accuracy: 0.001)
    }
}
