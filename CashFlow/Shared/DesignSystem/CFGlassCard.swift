import SwiftUI

struct CFGlassCard<Content: View>: View {
    var title: String?
    var subtitle: String?
    var padding: CGFloat = CFTheme.cardPadding
    @ViewBuilder var content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title {
                        Text(title)
                            .font(CFTheme.headline())
                            .foregroundStyle(CFTheme.textPrimary)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                }
            }
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { cardBackground }
    }

    @ViewBuilder
    private var cardBackground: some View {
        if colorScheme == .dark {
            RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                        .fill(CFTheme.accent.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                .fill(CFTheme.surfaceSecondary)
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: CFTheme.cardRadius, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                )
        }
    }
}
