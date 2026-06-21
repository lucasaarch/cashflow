import SwiftUI

/// Unified surface with sections separated by dividers.
struct CFPanel<Content: View>: View {
    var padding: CGFloat = 16
    var glass: Glass = .regular
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(glass, in: .rect(cornerRadius: CFGlassMetrics.panelCornerRadius))
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
                            .font(.callout)
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                trailing()
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint.opacity(0.85))
                }
                Text(label)
                    .font(CFTheme.dashboardLabel())
                    .foregroundStyle(CFTheme.textSecondary)
                    .lineLimit(1)
            }
            Text(amount.brl)
                .font(CFTheme.dashboardAmount())
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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
