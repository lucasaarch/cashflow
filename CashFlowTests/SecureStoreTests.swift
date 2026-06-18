import XCTest
@testable import CashFlow

final class SecureStoreTests: XCTestCase {
    override class func setUp() {
        SecureStore.setStorageScopeForTesting(".unit-tests")
    }

    override class func tearDown() {
        SecureStore.setStorageScopeForTesting(nil)
    }

    func testSaveReadRoundTrip() throws {
        try SecureStore.save("sk-ant-test-roundtrip", for: .anthropicAPIKey)
        XCTAssertEqual(SecureStore.read(.anthropicAPIKey), "sk-ant-test-roundtrip")
    }

    func testUpdateExistingValue() throws {
        try SecureStore.save("sk-ant-first", for: .anthropicAPIKey)
        try SecureStore.save("sk-ant-second", for: .anthropicAPIKey)
        XCTAssertEqual(SecureStore.read(.anthropicAPIKey), "sk-ant-second")
    }

    func testDeleteRemovesValue() throws {
        try SecureStore.save("sk-ant-delete", for: .anthropicAPIKey)
        SecureStore.delete(.anthropicAPIKey)
        XCTAssertNil(SecureStore.read(.anthropicAPIKey))
    }
}
