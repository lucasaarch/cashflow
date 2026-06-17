import SwiftUI

enum CFPillStyle { case primary, ghost, destructive }

struct CFPillButton: View {
    var title: String = ""
    var icon: String? = nil
    var iconOnly: Bool = false
    var style: CFPillStyle = .primary
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Group {
                if iconOnly, let icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                } else {
                    HStack(spacing: 6) {
                        if let icon {
                            Image(systemName: icon)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        if !title.isEmpty {
                            Text(title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
            }
            .padding(.horizontal, iconOnly ? 10 : 14)
            .padding(.vertical, 7)
            .background(background)
            .foregroundStyle(foreground)
            .clipShape(Capsule())
            .scaleEffect(isHovered ? 1.02 : 1)
            .animation(CFMotion.snappy, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Capsule().fill(CFTheme.accent)
        case .ghost:
            Capsule().fill(CFTheme.textTertiary.opacity(isHovered ? 0.15 : 0.08))
        case .destructive:
            Capsule().fill(CFTheme.danger.opacity(0.12))
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: return .white
        case .ghost: return CFTheme.textSecondary
        case .destructive: return CFTheme.danger
        }
    }
}
