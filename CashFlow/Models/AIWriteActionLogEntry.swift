import Foundation
import SwiftData

@Model
final class AIWriteActionLogEntry {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var toolName: String
    var summary: String
    var wasConfirmed: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        toolName: String,
        summary: String,
        wasConfirmed: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.toolName = toolName
        self.summary = summary
        self.wasConfirmed = wasConfirmed
    }
}

enum AIWriteActionLogger {
    @MainActor
    static func log(_ pending: AIPendingWriteAction, confirmed: Bool, in context: ModelContext) {
        let entry = AIWriteActionLogEntry(
            toolName: pending.toolName,
            summary: pending.summary,
            wasConfirmed: confirmed
        )
        context.insert(entry)
        try? context.save()
    }
}
