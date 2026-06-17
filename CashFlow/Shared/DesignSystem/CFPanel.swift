import SwiftUI

/// Unified surface with sections separated by dividers.
struct CFPanel<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { panelBackground }
    }

    @ViewBuilder
    private var panelBackground: some View {
        if colorScheme == .dark {
            RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                        .stroke(CFTheme.textTertiary.opacity(0.18), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                .fill(CFTheme.surfaceSecondary)
                .shadow(color: CFTheme.textPrimary.opacity(0.05), radius: 10, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                        .stroke(CFTheme.textTertiary.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
}

struct CFPanelSection<Content: View, Trailing: View>: View {
    let title: String
  var subtitle: String?
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CFTheme.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                trailing()
            }
            content()
        }
    }
}

struct CFStatChip: View {
    let label: String
    let amount: Decimal
    var tint: Color = CFTheme.textPrimary
    var icon: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.85))
                }
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(CFTheme.textSecondary)
                    .lineLimit(1)
            }
            Text(amount.brl)
                .font(.callout.weight(.semibold).monospacedDigit())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.07))
        )
    }
}

struct CFPanelDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 12)
    }
}
