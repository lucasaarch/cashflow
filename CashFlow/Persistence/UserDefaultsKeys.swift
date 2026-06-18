import Foundation

enum UserDefaultsKeys {
    static let hasSeededDefaults = "hasSeededDefaults"
    static let lastUsedAccountID = "lastUsedAccountID"
    static let lastUsedCategoryID = "lastUsedCategoryID"
    static let aiActiveProvider = "ai.activeProvider"
    static let aiActiveModelID = "ai.activeModelID"
    static let aiChatPanelWidth = "ai.chatPanelWidth"

    static func aiInsightCacheKey(monthKey: String) -> String {
        "ai.insight.\(monthKey)"
    }

    static func aiInsightCachedAtKey(monthKey: String) -> String {
        "ai.insight.\(monthKey).cachedAt"
    }

    static func aiWishlistInsightCacheKey(monthKey: String) -> String {
        "ai.wishlistInsight.\(monthKey)"
    }

    static func aiWishlistInsightCachedAtKey(monthKey: String) -> String {
        "ai.wishlistInsight.\(monthKey).cachedAt"
    }
}
