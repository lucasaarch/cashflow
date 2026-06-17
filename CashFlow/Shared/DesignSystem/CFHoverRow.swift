import SwiftUI

struct CFHoverRow<Content: View>: View {
    @ViewBuilder var content: () -> Content

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: CFTheme.rowRadius, style: .continuous)
                    .fill(rowBackground)
            )
            .scaleEffect(isHovered ? 1.005 : 1)
            .shadow(color: .black.opacity(isHovered ? 0.06 : 0), radius: 8, x: 0, y: 2)
            .animation(CFMotion.snappy, value: isHovered)
            .onHover { isHovered = $0 }
    }

    private var rowBackground: Color {
        if isHovered {
            return colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color.black.opacity(0.04)
        }
        return .clear
    }
}
