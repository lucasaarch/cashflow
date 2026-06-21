import Foundation
import SwiftData

@Model
final class ChatToolActivity {
    var callID: String
    var toolName: String
    var label: String
    var isComplete: Bool
    var isWrite: Bool
    var awaitingConfirmation: Bool = false
    var userConfirmed: Bool = false
    var userCancelled: Bool = false
    var sortOrder: Int

    var message: ChatMessage?

    init(
        callID: String,
        toolName: String,
        label: String,
        isComplete: Bool,
        isWrite: Bool,
        awaitingConfirmation: Bool = false,
        userConfirmed: Bool = false,
        userCancelled: Bool = false,
        sortOrder: Int,
        message: ChatMessage? = nil
    ) {
        self.callID = callID
        self.toolName = toolName
        self.label = label
        self.isComplete = isComplete
        self.isWrite = isWrite
        self.awaitingConfirmation = awaitingConfirmation
        self.userConfirmed = userConfirmed
        self.userCancelled = userCancelled
        self.sortOrder = sortOrder
        self.message = message
    }
}
