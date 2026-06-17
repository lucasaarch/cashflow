import SwiftUI

struct CFIconBadge: View {
    let symbolName: String
    var tint: Color
    var size: CGFloat = CFTheme.iconSize
    var cornerRadius: CGFloat? = nil // nil = circle

    var body: some View {
        let iconFontSize = size * 0.42
        let radius = cornerRadius ?? size / 2

        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(width: size, height: size)
            Image(systemName: symbolName)
                .font(.system(size: iconFontSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
    }
}
