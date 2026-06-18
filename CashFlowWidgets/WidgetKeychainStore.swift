import Foundation
import Security

// Keep in sync with CashFlow/Shared/Widgets/WidgetKeychainStore.swift

enum WidgetKeychainStore {
    private static let service = "com.cashflow.widget"
    private static let displayAccount = "widget-display"

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
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil),
              let groups = SecTaskCopyValueForEntitlement(task, "keychain-access-groups" as CFString, nil) as? [String]
        else { return nil }

        return groups.first { $0.hasSuffix("com.lucasarch.CashFlow") } ?? groups.first
        #else
        return nil
        #endif
    }
}
