import Foundation
import Security

enum SecureStore {
    enum Key: String {
        case openAIAPIKey = "com.cashflow.ai.openai.apiKey"
        case anthropicAPIKey = "com.cashflow.ai.anthropic.apiKey"
    }

    #if DEBUG
    /// Isolates unit tests from the user's real keychain entries (see `SecureStoreTests`).
    private static var storageScopeSuffix: String?

    static func setStorageScopeForTesting(_ suffix: String?) {
        storageScopeSuffix = suffix
    }
    #endif

    private static var service: String {
        let base = Bundle.main.bundleIdentifier ?? "com.lucasarch.CashFlow"
        #if DEBUG
        if let storageScopeSuffix { return base + storageScopeSuffix }
        #endif
        return base
    }

    static func save(_ value: String, for key: Key) throws {
        let data = Data(value.utf8)
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        SecItemDelete(legacyQuery(for: key) as CFDictionary)
        SecItemDelete(unscopedQuery(for: key) as CFDictionary)

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AIError.providerError("Falha ao salvar credencial (\(addStatus)).")
            }
            return
        }

        throw AIError.providerError("Falha ao salvar credencial (\(updateStatus)).")
    }

    static func read(_ key: Key) -> String? {
        if let value = readData(matching: readQuery(for: key)) {
            return value
        }

        if let value = readData(matching: unscopedReadQuery(for: key)) {
            try? save(value, for: key)
            return value
        }

        if let legacy = readData(matching: legacyReadQuery(for: key)) {
            try? save(legacy, for: key)
            SecItemDelete(legacyQuery(for: key) as CFDictionary)
            return legacy
        }

        return nil
    }

    static func delete(_ key: Key) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
        SecItemDelete(unscopedQuery(for: key) as CFDictionary)
        SecItemDelete(legacyQuery(for: key) as CFDictionary)
    }

    static func maskedValue(for key: Key) -> String? {
        guard let value = read(key), !value.isEmpty else { return nil }
        return "••••••••" + String(value.suffix(4))
    }

    // MARK: - Keychain queries

    private static func accessGroup() -> String? {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "keychain-access-groups" as CFString, nil) as? [String]
        else { return nil }
        return groups.first
    }

    private static func baseQuery(for key: Key) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        if let accessGroup = accessGroup() {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private static func readQuery(for key: Key) -> [String: Any] {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    /// Items saved before the access group was added to the keychain query.
    private static func unscopedQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }

    private static func unscopedReadQuery(for key: Key) -> [String: Any] {
        var query = unscopedQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    /// Pre-migration items stored without `kSecAttrService` (unstable across rebuilds in sandbox).
    private static func legacyQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
    }

    private static func legacyReadQuery(for key: Key) -> [String: Any] {
        var query = legacyQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    private static func readData(matching query: [String: Any]) -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
