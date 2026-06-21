import Foundation
import Security

enum SecureStore {
    enum Key: String {
        case openAIAPIKey = "com.cashflow.ai.openai.apiKey"
        case anthropicAPIKey = "com.cashflow.ai.anthropic.apiKey"
        case openAICompatibleAPIKey = "com.cashflow.ai.openaiCompatible.apiKey"
    }

    #if DEBUG
    /// Isolates unit tests from the user's real keychain entries (see `SecureStoreTests`).
    nonisolated(unsafe) private static var storageScopeSuffix: String?

    nonisolated static func setStorageScopeForTesting(_ suffix: String?) {
        storageScopeSuffix = suffix
    }
    #endif

    nonisolated private static var service: String {
        let base = Bundle.main.bundleIdentifier ?? "com.lucasarch.CashFlow"
        #if DEBUG
        if let storageScopeSuffix { return base + storageScopeSuffix }
        #endif
        return base
    }

    nonisolated static func save(_ value: String, for key: Key) throws {
        let data = Data(value.utf8)
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

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

    nonisolated static func read(_ key: Key) -> String? {
        if let value = readData(matching: readQuery(for: key)) {
            return value
        }

        #if DEBUG
        if storageScopeSuffix != nil {
            return nil
        }
        #endif

        if let value = readData(matching: unscopedReadQuery(for: key)) {
            try? save(value, for: key)
            SecItemDelete(unscopedQuery(for: key) as CFDictionary)
            return value
        }

        if let legacy = readData(matching: legacyReadQuery(for: key)) {
            try? save(legacy, for: key)
            SecItemDelete(legacyQuery(for: key) as CFDictionary)
            return legacy
        }

        return nil
    }

    nonisolated static func delete(_ key: Key) {
        SecItemDelete(baseQuery(for: key) as CFDictionary)
        SecItemDelete(unscopedQuery(for: key) as CFDictionary)
        #if DEBUG
        if storageScopeSuffix == nil {
            SecItemDelete(legacyQuery(for: key) as CFDictionary)
        }
        #else
        SecItemDelete(legacyQuery(for: key) as CFDictionary)
        #endif
    }

    nonisolated static func maskedValue(for key: Key) -> String? {
        guard let value = read(key), !value.isEmpty else { return nil }
        return "••••••••" + String(value.suffix(4))
    }

    nonisolated static func saveCustomProviderAPIKey(_ value: String, providerID: UUID) throws {
        try save(value, account: customProviderAccount(providerID))
    }

    nonisolated static func readCustomProviderAPIKey(_ providerID: UUID) -> String? {
        read(account: customProviderAccount(providerID))
    }

    nonisolated static func deleteCustomProviderAPIKey(_ providerID: UUID) {
        delete(account: customProviderAccount(providerID))
    }

    nonisolated static func maskedCustomProviderAPIKey(_ providerID: UUID) -> String? {
        maskedValue(account: customProviderAccount(providerID))
    }

    nonisolated static func save(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

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

    nonisolated static func read(account: String) -> String? {
        readData(matching: readQuery(account: account))
    }

    nonisolated static func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }

    nonisolated static func maskedValue(account: String) -> String? {
        guard let value = read(account: account), !value.isEmpty else { return nil }
        return "••••••••" + String(value.suffix(4))
    }

    nonisolated private static func customProviderAccount(_ providerID: UUID) -> String {
        "com.cashflow.ai.customProvider.\(providerID.uuidString)"
    }

    // MARK: - Keychain queries

    nonisolated private static func accessGroup() -> String? {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "keychain-access-groups" as CFString, nil) as? [String]
        else { return nil }
        return groups.first
    }

    nonisolated private static func baseQuery(for key: Key) -> [String: Any] {
        baseQuery(account: key.rawValue)
    }

    nonisolated private static func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup = accessGroup() {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    nonisolated private static func readQuery(for key: Key) -> [String: Any] {
        readQuery(account: key.rawValue)
    }

    nonisolated private static func readQuery(account: String) -> [String: Any] {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    /// Items saved before the access group was added to the keychain query.
    nonisolated private static func unscopedQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
    }

    nonisolated private static func unscopedReadQuery(for key: Key) -> [String: Any] {
        var query = unscopedQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    /// Pre-migration items stored without `kSecAttrService` (unstable across rebuilds in sandbox).
    nonisolated private static func legacyQuery(for key: Key) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
    }

    nonisolated private static func legacyReadQuery(for key: Key) -> [String: Any] {
        var query = legacyQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        return query
    }

    nonisolated private static func readData(matching query: [String: Any]) -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
