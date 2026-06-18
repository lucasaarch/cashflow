import XCTest
import SwiftData
@testable import CashFlow

@MainActor
final class WishlistSortOrderTests: XCTestCase {
    func testSortsByPriorityThenDesiredBy() {
        let cal = Calendar.current
        let soon = cal.date(byAdding: .day, value: 3, to: .now)!
        let later = cal.date(byAdding: .day, value: 30, to: .now)!

        let low = WishlistItem(name: "Calça", estimatedAmount: 200, priority: .low)
        let urgentSoon = WishlistItem(name: "Fone", estimatedAmount: 800, priority: .urgent, desiredBy: soon)
        let urgentLater = WishlistItem(name: "Cadeira", estimatedAmount: 1200, priority: .urgent, desiredBy: later)
        let highNoDate = WishlistItem(name: "Mouse", estimatedAmount: 300, priority: .high)

        let sorted = WishlistSortOrder.sorted([low, urgentSoon, urgentLater, highNoDate])

        XCTAssertEqual(sorted.map(\.name), ["Fone", "Cadeira", "Mouse", "Calça"])
    }
}
