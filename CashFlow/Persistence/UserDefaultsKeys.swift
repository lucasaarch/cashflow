import Foundation

enum UserDefaultsKeys {
    static let hasSeededDefaults = "hasSeededDefaults"
    static let lastUsedAccountID = "lastUsedAccountID"
    static let lastUsedCategoryID = "lastUsedCategoryID"
    static let monthlyIncomeCents = "monthlyIncomeCents"
    static let aiActiveProvider = "ai.activeProvider"
    static let aiActiveModelID = "ai.activeModelID"
    static let aiOllamaHost = "ai.ollamaHost"
    static let aiOllamaPort = "ai.ollamaPort"

    static func aiInsightCacheKey(monthKey: String) -> String {
        "ai.insight.\(monthKey)"
    }

    static func aiInsightCachedAtKey(monthKey: String) -> String {
        "ai.insight.\(monthKey).cachedAt"
    }
}
