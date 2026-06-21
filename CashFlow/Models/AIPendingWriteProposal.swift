import Foundation
import SwiftData

@Model
final class AIPendingWriteProposal {
    @Attribute(.unique) var id: UUID
    var toolCallID: String
    var toolName: String
    var argumentsJSON: String
    var summary: String
    var sourceRaw: String
    var createdAt: Date

    init(from action: AIPendingWriteAction, createdAt: Date = .now) {
        id = action.id
        toolCallID = action.toolCallID
        toolName = action.toolName
        argumentsJSON = action.argumentsJSON
        summary = action.summary
        sourceRaw = action.source.rawValue
        self.createdAt = createdAt
    }

    func asPendingWriteAction() -> AIPendingWriteAction {
        AIPendingWriteAction(
            id: id,
            toolCallID: toolCallID,
            toolName: toolName,
            argumentsJSON: argumentsJSON,
            summary: summary,
            source: AIPendingWriteAction.Source(rawValue: sourceRaw) ?? .mcp
        )
    }
}

enum MCPWriteProposalPersistence {
    @MainActor
    static func save(_ action: AIPendingWriteAction, in context: ModelContext) {
        let id = action.id
        if let existing = try? context.fetch(FetchDescriptor<AIPendingWriteProposal>(
            predicate: #Predicate { $0.id == id }
        )).first {
            context.delete(existing)
        }
        context.insert(AIPendingWriteProposal(from: action))
        try? context.save()
    }

    @MainActor
    static func remove(_ id: UUID, in context: ModelContext) {
        guard let existing = try? context.fetch(FetchDescriptor<AIPendingWriteProposal>(
            predicate: #Predicate { $0.id == id }
        )).first else { return }
        context.delete(existing)
        try? context.save()
    }

    @MainActor
    static func restorePending(into store: MCPWriteProposalStore, container: ModelContainer) {
        let context = container.mainContext
        guard let proposals = try? context.fetch(
            FetchDescriptor<AIPendingWriteProposal>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        ), let latest = proposals.first else { return }

        if store.pendingWrite == nil {
            store.present(latest.asPendingWriteAction())
        }
    }
}
