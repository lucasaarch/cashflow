import Foundation
import Security

/// macOS widget extensions often cannot read the App Group container; Keychain sharing works reliably.
enum WidgetKeychainStore {
    private static let service = "com.cashflow.widget"
    private static let displayAccount = "widget-display"

    @discardableResult
    static func saveDisplay(_ display: WidgetDisplayPayload) -> Bool {
        guard let data = try? JSONEncoder().encode(display) else { return false }

        let query = baseQuery()
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        guard updateStatus == errSecItemNotFound else { return false }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    static func loadDisplay() -> WidgetDisplayPayload? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let display = try? JSONDecoder().decode(WidgetDisplayPayload.self, from: data),
              display.hasContent
        else { return nil }

        return display
    }

    private static func baseQuery() -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: displayAccount
        ]

        if let accessGroup = sharedAccessGroup() {
            query[kSecAttrAccessGroup as String] = accessGroup
        }

        return query
    }

    private static func sharedAccessGroup() -> String? {
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "keychain-access-groups" as CFString, nil) as? [String]
        else { return nil }

        return groups.first { $0.hasSuffix("com.lucasarch.CashFlow") } ?? groups.first
    }
}
