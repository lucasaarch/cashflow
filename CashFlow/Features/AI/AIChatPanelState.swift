import Combine
import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
    @Published private(set) var liveToolActivities: [AIToolActivityRecord] = []
    @Published private(set) var toolActivitiesByMessageID: [UUID: [AIToolActivityRecord]] = [:]
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
            close()
        } else {
            openFresh()
        }
    }

    func close() {
        setOpen(false)
    }

    func openFresh() {
        clearInsightDiscussionContext()
        setOpen(true)
    }

    /// Opens the panel without clearing insight context (e.g. MCP write proposal).
    func ensureOpen(animated: Bool = true) {
        guard !isOpen else { return }
        setOpen(true, animated: animated)
    }

    private static var prefersReducedMotion: Bool {
        #if os(macOS)
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        UIAccessibility.isReduceMotionEnabled
        #endif
    }

    private func setOpen(_ open: Bool, animated: Bool = true) {
        guard animated, !Self.prefersReducedMotion, !isResizing else {
            var transaction = SwiftUI.Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isOpen = open
            }
            return
        }
        withAnimation(CFMotion.quick) {
            isOpen = open
        }
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
        setOpen(true)
    }

    private func clearInsightDiscussionContext() {
        dashboardInsightMonthKey = nil
        wishlistInsightMonthKey = nil
        insightLaunchToken = nil
    }

    private static func clampWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minPanelWidth), maxPanelWidth)
    }

    func beginToolTrace() {
        liveToolActivities = []
    }

    func handleAgentStatus(_ update: AIAgentStatusUpdate, treatWriteToolsAsProposals: Bool = false) {
        switch update.kind {
        case .thinking:
            break
        case .toolStarted(let name, let callID):
            upsertActivity(
                callID: callID,
                toolName: name,
                isComplete: false,
                treatWriteToolsAsProposals: treatWriteToolsAsProposals
            )
        case .toolFinished(let name, let callID):
            upsertActivity(
                callID: callID,
                toolName: name,
                isComplete: true,
                treatWriteToolsAsProposals: treatWriteToolsAsProposals
            )
        }
    }

    func finalizeToolTrace(for messageID: UUID, message: ChatMessage? = nil, context: ModelContext? = nil) {
        guard !liveToolActivities.isEmpty else { return }
        toolActivitiesByMessageID[messageID] = liveToolActivities
        if let message, let context {
            message.replaceToolActivities(liveToolActivities, in: context)
            try? context.save()
        }
        liveToolActivities = []
    }

    func toolActivities(for messageID: UUID) -> [AIToolActivityRecord] {
        toolActivitiesByMessageID[messageID] ?? []
    }

    func markWriteProposalConfirmed(callID: String, toolName: String) {
        resolveWriteProposalActivity(callID: callID, toolName: toolName) { index in
            liveToolActivities[index].awaitingConfirmation = false
            liveToolActivities[index].userConfirmed = true
            liveToolActivities[index].userCancelled = false
            liveToolActivities[index].isComplete = true
        }
    }

    func markWriteProposalCancelled(callID: String, toolName: String) {
        resolveWriteProposalActivity(callID: callID, toolName: toolName) { index in
            liveToolActivities[index].awaitingConfirmation = false
            liveToolActivities[index].userConfirmed = false
            liveToolActivities[index].userCancelled = true
            liveToolActivities[index].isComplete = true
        }
    }

    func visibleToolActivities(_ activities: [AIToolActivityRecord]) -> [AIToolActivityRecord] {
        activities.filter(\.isVisibleInChat)
    }

    private func resolveWriteProposalActivity(
        callID: String,
        toolName: String,
        update: (Int) -> Void
    ) {
        if let index = liveToolActivities.firstIndex(where: { $0.id == callID }) {
            update(index)
            return
        }
        if let index = liveToolActivities.lastIndex(where: {
            $0.toolName == toolName && $0.isWrite && $0.awaitingConfirmation
        }) {
            update(index)
            return
        }
        liveToolActivities.append(
            AIToolActivityRecord(
                id: callID,
                toolName: toolName,
                label: AIToolDisplayName.label(for: toolName),
                isComplete: true,
                isWrite: true
            )
        )
        update(liveToolActivities.count - 1)
    }

    func openWithDraft(_ draft: String, autoSend: Bool = false) {
        clearInsightDiscussionContext()
        self.draft = draft
        if autoSend {
            insightLaunchToken = UUID()
        }
        setOpen(true)
    }

    func openToDiscussBill(_ bill: Bill) {
        openWithDraft("Quero pagar a conta \"\(bill.name)\" de \(bill.amount.brl).", autoSend: true)
    }

    func openToDiscussReceivable(_ receivable: Receivable) {
        openWithDraft(
            "Quero confirmar o recebimento de \"\(receivable.name)\" de \(receivable.amount.brl).",
            autoSend: true
        )
    }

    func openToRegisterExpense() {
        openWithDraft("Quero registrar uma despesa.", autoSend: true)
    }

    func openToRegisterIncome() {
        openWithDraft("Quero registrar uma receita.", autoSend: true)
    }

    func adoptPendingWriteFromMCPStore() {
        if pendingWrite == nil, let storePending = MCPWriteProposalStore.shared.pendingWrite {
            pendingWrite = storePending
        }
    }

    private func upsertActivity(
        callID: String,
        toolName: String,
        isComplete: Bool,
        treatWriteToolsAsProposals: Bool
    ) {
        let isWrite = AIToolCatalog.definition(named: toolName)?.isWrite ?? false
        let label = AIToolDisplayName.label(for: toolName)
        let awaitingConfirmation = treatWriteToolsAsProposals && isWrite && isComplete

        if let index = liveToolActivities.firstIndex(where: { $0.id == callID }) {
            liveToolActivities[index].isComplete = isComplete
            liveToolActivities[index].awaitingConfirmation = awaitingConfirmation
        } else {
            liveToolActivities.append(
                AIToolActivityRecord(
                    id: callID,
                    toolName: toolName,
                    label: label,
                    isComplete: isComplete,
                    isWrite: isWrite,
                    awaitingConfirmation: awaitingConfirmation
                )
            )
        }
    }
}
