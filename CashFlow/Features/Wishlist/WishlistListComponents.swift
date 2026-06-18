import SwiftUI
import SwiftData

struct WishlistSummaryHeader: View {
    @EnvironmentObject private var privacy: PrivacyMode

    let totalEstimated: Decimal
    let items: [WishlistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total estimado")
                .font(CFTheme.caption().weight(.medium))
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)

            CFAnimatedAmount(
                amount: totalEstimated,
                font: CFTheme.heroAmount(),
                color: CFTheme.textPrimary
            )

            if let breakdown = breakdownText {
                Text(breakdown)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    private var breakdownText: String? {
        guard !items.isEmpty else { return nil }
        var parts: [String] = [
            "\(items.count) \(items.count == 1 ? "item" : "itens")"
        ]
        let urgent = items.filter { $0.priority == .urgent }.count
        if urgent > 0 {
            parts.append("\(urgent) urgente\(urgent == 1 ? "" : "s")")
        }
        let withDate = items.filter { $0.desiredBy != nil }.count
        if withDate > 0 {
            parts.append("\(withDate) com prazo")
        }
        return parts.joined(separator: " · ")
    }
}

struct WishlistItemRow: View {
    @EnvironmentObject private var privacy: PrivacyMode

    let item: WishlistItem
    var iconSize: CGFloat = 34
    var nameFont: Font = CFTheme.body().weight(.medium)
    var amountFont: Font = CFTheme.kpiValue()

    var body: some View {
        HStack(spacing: 12) {
            CFIconBadge(
                symbolName: item.category?.symbolName ?? "cart.fill",
                tint: priorityTint(item.priority),
                size: iconSize
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(nameFont)
                    .foregroundStyle(CFTheme.textPrimary)
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }
            Spacer(minLength: 0)
            Text(item.estimatedAmount.brl(masked: privacy.valuesHidden))
                .font(amountFont)
                .foregroundStyle(CFTheme.textPrimary)
        }
    }

    private var subtitleText: String? {
        var parts: [String] = [item.priority.displayName]
        if let category = item.category?.name {
            parts.append(category)
        }
        if let desiredBy = item.desiredBy {
            parts.append("até \(desiredBy.cfRelativeOrAbsoluteDay())")
        }
        return parts.joined(separator: " · ")
    }

    private func priorityTint(_ priority: WishlistPriority) -> Color {
        switch priority {
        case .urgent: return CFTheme.danger
        case .high: return CFTheme.warning
        case .medium: return CFTheme.accent
        case .low: return CFTheme.textSecondary
        }
    }
}
