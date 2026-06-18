import Combine
import SwiftUI

@MainActor
final class AIChatPanelState: ObservableObject {
    static let defaultPanelWidth: CGFloat = 380
    static let minPanelWidth: CGFloat = 320
    static let maxPanelWidth: CGFloat = 720

    @Published var isOpen = false
    @Published var selectedConversationID: UUID?
    @Published var draft = ""
    @Published var isResizing = false
    @Published private(set) var panelWidth: CGFloat
    @Published var pendingWrite: AIPendingWriteAction?
    @Published var agentMessages: [AIMessage] = []
    @Published var toolStatusMessage: String?
    /// Assistant messages whose typewriter animation has already played. The list
    /// view sits in a LazyVStack, so views are recreated when scrolled offscreen;
    /// without this we'd replay the reveal every time.
    @Published var typedMessageIDs: Set<UUID> = []
    /// When set, `get_dashboard_insight` prefers this month (yyyy-MM).
    @Published var dashboardInsightMonthKey: String?
    /// When set, `get_wishlist_insight` prefers this month (yyyy-MM).
    @Published var wishlistInsightMonthKey: String?
    /// Signals AIChatSidePanel to focus the input and auto-send the current draft.
    @Published private(set) var insightLaunchToken: UUID?

    init() {
        let saved = UserDefaults.standard.double(forKey: UserDefaultsKeys.aiChatPanelWidth)
        if saved > 0 {
            panelWidth = Self.clampWidth(CGFloat(saved))
        } else {
            panelWidth = Self.defaultPanelWidth
        }
    }

    func toggle() {
        if isOpen {
            isOpen = false
        } else {
            openFresh()
        }
    }

    func close() { isOpen = false }

    func openFresh() {
        clearInsightDiscussionContext()
        isOpen = true
    }

    func openToDiscussDashboardInsight(referenceDate: Date, calendar: Calendar = .current) {
        let monthKey = AIInsightsService.monthKey(for: referenceDate, calendar: calendar)
        let monthLabel = referenceDate
            .formatted(.dateTime.month(.wide).year().locale(Money.locale))
            .capitalized
        openForInsightDiscussion(
            dashboardMonthKey: monthKey,
            wishlistMonthKey: nil,
            draft: "Quero conversar sobre o resumo da \(AIAssistantIdentity.name) de \(monthLabel)."
        )
    }

    func openToDiscussWishlistInsight(referenceDate: Date, calendar: Calendar = .current) {
        let monthKey = AIInsightsService.monthKey(for: referenceDate, calendar: calendar)
        let monthLabel = referenceDate
            .formatted(.dateTime.month(.wide).year().locale(Money.locale))
            .capitalized
        openForInsightDiscussion(
            dashboardMonthKey: nil,
            wishlistMonthKey: monthKey,
            draft: "Quero conversar sobre a sugestão da lista de desejos de \(monthLabel)."
        )
    }

    func consumeInsightLaunchToken() -> UUID? {
        let token = insightLaunchToken
        insightLaunchToken = nil
        return token
    }

    func setPanelWidth(_ width: CGFloat) {
        let clamped = Self.clampWidth(width)
        guard clamped != panelWidth else { return }
        panelWidth = clamped
        UserDefaults.standard.set(Double(clamped), forKey: UserDefaultsKeys.aiChatPanelWidth)
    }

    private func openForInsightDiscussion(
        dashboardMonthKey: String?,
        wishlistMonthKey: String?,
        draft: String
    ) {
        clearInsightDiscussionContext()
        dashboardInsightMonthKey = dashboardMonthKey
        wishlistInsightMonthKey = wishlistMonthKey
        self.draft = draft
        insightLaunchToken = UUID()
        isOpen = true
    }

    private func clearInsightDiscussionContext() {
        dashboardInsightMonthKey = nil
        wishlistInsightMonthKey = nil
        insightLaunchToken = nil
    }

    private static func clampWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minPanelWidth), maxPanelWidth)
    }
}
