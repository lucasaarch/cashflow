import SwiftUI

struct CFProgressBar: View {
    let progress: Double // 0...1 for display width
    var color: Color = CFTheme.accent
    var height: CGFloat = 8

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animatedProgress: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(CFTheme.textTertiary.opacity(0.15))
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(4, geo.size.width * min(animatedProgress, 1)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .onAppear {
            if reduceMotion {
                animatedProgress = progress
            } else {
                withAnimation(CFMotion.bouncy.delay(0.1)) {
                    animatedProgress = progress
                }
            }
        }
        .onChange(of: progress) { _, newValue in
            Task { @MainActor in
                withAnimation(reduceMotion ? nil : CFMotion.gentle) {
                    animatedProgress = newValue
                }
            }
        }
    }
}
