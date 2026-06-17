import SwiftUI

/// Single shimmering placeholder bar. Use a VStack to stack multiple lines.
struct CFSkeletonLine: View {
    var height: CGFloat = 10
    var widthFraction: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let barWidth = proxy.size.width * widthFraction
            let highlightWidth = max(barWidth * 0.45, 60)
            let travel = barWidth + highlightWidth
            let shape = RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            let base = CFTheme.textTertiary.opacity(0.18)
            let highlight = CFTheme.textTertiary.opacity(0.45)

            ZStack(alignment: .leading) {
                shape.fill(base)

                if !reduceMotion {
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0),
                            .init(color: highlight, location: 0.5),
                            .init(color: .clear, location: 1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: highlightWidth)
                    .offset(x: phase * travel - highlightWidth)
                }
            }
            .frame(width: barWidth, height: height, alignment: .leading)
            .clipShape(shape)
        }
        .frame(height: height)
        .onAppear {
            guard !reduceMotion else { return }
            phase = 0
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}
