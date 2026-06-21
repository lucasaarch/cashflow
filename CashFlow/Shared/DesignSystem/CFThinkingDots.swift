import SwiftUI

/// Indicador de pensamento — três pontos com bounce escalonado.
struct CFThinkingDots: View {
    enum Style {
        case inline
        case panel
    }

    var style: Style = .inline

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    private var dotSize: CGFloat { style == .panel ? 8 : 7 }
    private var spacing: CGFloat { style == .panel ? 6 : 5 }
    private var bounce: CGFloat { style == .panel ? 6 : 5 }

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(CFTheme.textTertiary)
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: animating ? -bounce : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.38)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.14),
                        value: animating
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: dotSize + bounce)
        .accessibilityLabel("Gio está pensando")
        .onAppear {
            animating = true
        }
    }
}
