import SwiftUI

/// Typing / thinking indicator — three dots with staggered bounce.
struct CFThinkingDots: View {
    var dotSize: CGFloat = 7
    var spacing: CGFloat = 5
    var bounce: CGFloat = 5
    var color: Color = CFTheme.textSecondary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animating = false

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .offset(y: animating ? -bounce : 0)
                    .animation(
                        CFMotion.animation(
                            .easeInOut(duration: 0.38)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.14),
                            reduceMotion: reduceMotion
                        ),
                        value: animating
                    )
            }
        }
        .frame(height: dotSize + bounce)
        .accessibilityLabel("Pensando")
        .onAppear {
            animating = true
        }
    }
}
