import Foundation

enum UserDefaultsKeys {
    static let lastUsedAccountID = "lastUsedAccountID"
    static let lastUsedCategoryID = "lastUsedCategoryID"
    static let aiActiveProvider = "ai.activeProvider"
    static let aiActiveModelID = "ai.activeModelID"
    static let aiCustomProviders = "ai.customProviders"
    static let aiOpenAICompatibleBaseURL = "ai.openAICompatible.baseURL"
    static let aiOpenAICompatibleSupportsTools = "ai.openAICompatible.supportsTools"
    static let aiOpenAICompatibleDidConnect = "ai.openAICompatible.didConnect"
    static let aiChatPanelWidth = "ai.chatPanelWidth"
    static let aiFavoriteModels = "ai.favoriteModels"
    static let weeklyReminderEnabled = "notifications.weeklyReminderEnabled"
    static let weeklyReminderLastScheduledWeek = "notifications.weeklyReminderLastScheduledWeek"
    static let mcpServerEnabled = "mcp.serverEnabled"

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
