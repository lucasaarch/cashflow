import XCTest
@testable import CashFlow

@MainActor
final class WidgetSnapshotTests: XCTestCase {
    func testRoundTripEncoding() throws {
        let original = WidgetSnapshot.placeholder
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testMinorUnitsConversion() {
        XCTAssertEqual(Decimal(string: "184.46")!.minorUnits, 18_446)
        XCTAssertEqual(Decimal(minorUnits: 18_446), Decimal(string: "184.46"))
    }

    func testFileStoreRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("widget-snapshot.json")

        let original = WidgetSnapshot.placeholder
        let data = try JSONEncoder().encode(original)
        try data.write(to: fileURL)

        let loaded = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: fileURL))
        XCTAssertEqual(loaded, original)
    }

    func testDecodeLiveAppGroupSnapshotIfPresent() throws {
        guard let loaded = WidgetSnapshotStore.load() else {
            throw XCTSkip("No live widget snapshot available")
        }
        XCTAssertTrue(loaded.hasData)
        XCTAssertNotEqual(loaded.liquidBalanceMinorUnits, 0)
    }
}
