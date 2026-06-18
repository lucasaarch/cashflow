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

    init() {
        let saved = UserDefaults.standard.double(forKey: UserDefaultsKeys.aiChatPanelWidth)
        if saved > 0 {
            panelWidth = Self.clampWidth(CGFloat(saved))
        } else {
            panelWidth = Self.defaultPanelWidth
        }
    }

    func toggle() { isOpen.toggle() }
    func close() { isOpen = false }
    func open() { isOpen = true }

    func setPanelWidth(_ width: CGFloat) {
        let clamped = Self.clampWidth(width)
        guard clamped != panelWidth else { return }
        panelWidth = clamped
        UserDefaults.standard.set(Double(clamped), forKey: UserDefaultsKeys.aiChatPanelWidth)
    }

    private static func clampWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minPanelWidth), maxPanelWidth)
    }
}
