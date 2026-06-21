import Combine
import Foundation

extension Notification.Name {
    static let mcpWriteProposalCreated = Notification.Name("mcpWriteProposalCreated")
}

@MainActor
final class MCPWriteProposalStore: ObservableObject {
    static let shared = MCPWriteProposalStore()

    @Published private(set) var pendingWrite: AIPendingWriteAction?

    private init() {}

    func present(_ action: AIPendingWriteAction) {
        pendingWrite = action
        NotificationCenter.default.post(name: .mcpWriteProposalCreated, object: action)
    }

    func clear() {
        pendingWrite = nil
    }
}
