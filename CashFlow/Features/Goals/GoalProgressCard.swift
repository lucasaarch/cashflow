import SwiftUI

struct GoalProgressCard: View {
    let snapshot: GoalProgressSnapshot
    var goal: FinancialGoal?
    var compact: Bool = false

    @EnvironmentObject private var privacy: PrivacyMode

    private var tint: Color {
        if let goal { return Color(hex: goal.colorHex) }
        return CFTheme.accent
    }

    private var symbol: String {
        goal?.symbolName ?? "flag.fill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack(spacing: 10) {
                CFIconBadge(symbolName: symbol, tint: tint, size: compact ? 26 : 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.name)
                        .font(compact ? .callout.weight(.medium) : CFTheme.body())
                        .foregroundStyle(CFTheme.textPrimary)
                    Text(progressCaption)
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                }
                Spacer()
                if !compact {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(snapshot.currentAmount.brl(masked: privacy.valuesHidden))
                            .font(.callout.monospacedDigit().weight(.semibold))
                        Text("de \(snapshot.targetAmount.brl(masked: privacy.valuesHidden))")
                            .font(.caption2)
                            .foregroundStyle(CFTheme.textTertiary)
                    }
                }
            }

            CFProgressBar(
                progress: snapshot.progress,
                color: snapshot.isCompleted ? CFTheme.income : tint,
                height: compact ? 6 : 8
            )

            if let monthlyNeeded = snapshot.monthlyNeeded, !snapshot.isCompleted {
                Text("Faltam \(snapshot.remaining.brl(masked: privacy.valuesHidden)) · \(monthlyNeeded.brl(masked: privacy.valuesHidden))/mês até a meta")
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textTertiary)
            }
        }
    }

    private var progressCaption: String {
        if snapshot.isCompleted { return "Meta concluída" }
        let percent = Int(snapshot.progress * 100)
        return "\(percent)% · vinculada a contas"
    }
}
