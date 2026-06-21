import SwiftUI

struct AIToolActivityBubble: View {
    let record: AIToolActivityRecord

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: AIToolDisplayName.symbol(for: record.toolName))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 18)

            Text(record.label)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            statusIndicator
        }
        .cfChatActivityBubbleGlass(strokeColor: strokeColor)
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if record.userConfirmed {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CFTheme.income)
        } else if record.userCancelled {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CFTheme.danger)
        } else if record.isComplete {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(CFTheme.income)
        } else {
            ProgressView()
                .controlSize(.mini)
        }
    }

    private var strokeColor: Color {
        if record.userConfirmed { return CFTheme.income.opacity(0.35) }
        if record.userCancelled { return CFTheme.danger.opacity(0.35) }
        return CFTheme.textTertiary.opacity(0.14)
    }

    private var statusColor: Color {
        if record.userConfirmed { return CFTheme.income }
        if record.userCancelled { return CFTheme.danger }
        return record.isWrite ? CFTheme.warning : CFTheme.textSecondary
    }
}

struct AIToolActivityStack: View {
    let activities: [AIToolActivityRecord]

    var body: some View {
        let visible = activities.filter(\.isVisibleInChat)
        if !visible.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(visible) { activity in
                    AIToolActivityBubble(record: activity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
