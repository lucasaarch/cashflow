import XCTest
@testable import CashFlow

final class SecureStoreTests: XCTestCase {
    override class func setUp() {
        SecureStoreTestIsolation.activate()
    }

    override class func tearDown() {
        SecureStoreTestIsolation.deactivate()
    }

    func testSaveReadRoundTrip() async throws {
        try await secureStoreSave("sk-ant-test-roundtrip", for: .anthropicAPIKey)
        let value = await secureStoreRead(.anthropicAPIKey)

        XCTAssertEqual(value, "sk-ant-test-roundtrip")
    }

    func testUpdateExistingValue() async throws {
        try await secureStoreSave("sk-ant-first", for: .anthropicAPIKey)
        try await secureStoreSave("sk-ant-second", for: .anthropicAPIKey)
        let value = await secureStoreRead(.anthropicAPIKey)

        XCTAssertEqual(value, "sk-ant-second")
    }

    func testDeleteRemovesValue() async throws {
        try await secureStoreSave("sk-ant-delete", for: .anthropicAPIKey)
        await secureStoreDelete(.anthropicAPIKey)
        let value = await secureStoreRead(.anthropicAPIKey)

        XCTAssertNil(value)
    }

    private func secureStoreSave(_ value: String, for key: SecureStore.Key) async throws {
        try await Task.detached {
            try SecureStore.save(value, for: key)
        }.value
    }

    private func secureStoreRead(_ key: SecureStore.Key) async -> String? {
        await Task.detached {
            SecureStore.read(key)
        }.value
    }

    private func secureStoreDelete(_ key: SecureStore.Key) async {
        await Task.detached {
            SecureStore.delete(key)
        }.value
    }
}
