import SwiftUI
import SwiftData

struct WishlistSummaryHeader: View {

    let totalEstimated: Decimal
    let items: [WishlistItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CFAnimatedAmount(
                amount: totalEstimated,
                font: CFTheme.heroAmount(),
                color: CFTheme.textPrimary
            )

            if let breakdown = breakdownText {
                Text(breakdown)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var breakdownText: String? {
        guard !items.isEmpty else { return nil }
        var parts: [String] = []
        let urgent = items.filter { $0.priority == .urgent }.count
        if urgent > 0 {
            parts.append("\(urgent) urgente\(urgent == 1 ? "" : "s")")
        }
        let withDate = items.filter { $0.desiredBy != nil }.count
        if withDate > 0 {
            parts.append("\(withDate) com prazo")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }
}

struct WishlistItemRow: View {

    let item: WishlistItem
    var iconSize: CGFloat = 34
    var nameFont: Font = CFTheme.body().weight(.medium)
    var amountFont: Font = CFTheme.kpiValue()

    var body: some View {
        HStack(spacing: 12) {
            CFGlassSymbol(
                systemName: item.category?.symbolName ?? "cart.fill",
                tint: priorityTint(item.priority),
                size: iconSize
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(nameFont)
                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Text(item.estimatedAmount.brl)
                .font(amountFont)
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
