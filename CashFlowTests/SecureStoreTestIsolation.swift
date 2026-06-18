import XCTest
@testable import CashFlow

/// Routes keychain reads/writes to an isolated service scope during tests.
enum SecureStoreTestIsolation {
    static let scopeSuffix = ".unit-tests"

    static func activate() {
        SecureStore.setStorageScopeForTesting(scopeSuffix)
    }

    static func deactivate() {
        SecureStore.setStorageScopeForTesting(nil)
    }
}
