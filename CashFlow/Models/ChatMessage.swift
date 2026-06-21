import Foundation
import SwiftData

@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var roleRaw: String
    var content: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatToolActivity.message)
    var toolActivities: [ChatToolActivity] = []

    var conversation: ChatConversation?

    var role: AIMessageRole {
        get { AIMessageRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        role: AIMessageRole,
        content: String,
        createdAt: Date = .now,
        conversation: ChatConversation? = nil
    ) {
        self.id = id
        self.roleRaw = role.rawValue
        self.content = content
        self.createdAt = createdAt
        self.conversation = conversation
    }
}
