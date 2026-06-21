import Foundation
import SwiftData

extension ChatMessage {
    var sortedToolActivityRecords: [AIToolActivityRecord] {
        toolActivities
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                AIToolActivityRecord(
                    id: $0.callID,
                    toolName: $0.toolName,
                    label: $0.label,
                    isComplete: $0.isComplete,
                    isWrite: $0.isWrite,
                    awaitingConfirmation: $0.awaitingConfirmation,
                    userConfirmed: $0.userConfirmed,
                    userCancelled: $0.userCancelled
                )
            }
    }

    func replaceToolActivities(_ records: [AIToolActivityRecord], in context: ModelContext) {
        for existing in toolActivities {
            context.delete(existing)
        }
        toolActivities.removeAll()

        for (index, record) in records.enumerated() {
            let activity = ChatToolActivity(
                callID: record.id,
                toolName: record.toolName,
                label: record.label,
                isComplete: record.isComplete,
                isWrite: record.isWrite,
                awaitingConfirmation: record.awaitingConfirmation,
                userConfirmed: record.userConfirmed,
                userCancelled: record.userCancelled,
                sortOrder: index,
                message: self
            )
            context.insert(activity)
            toolActivities.append(activity)
        }
    }
}
