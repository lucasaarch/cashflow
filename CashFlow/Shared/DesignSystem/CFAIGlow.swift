import SwiftUI

struct CFAIGlowModifier: ViewModifier {
    let active: Bool
    let cornerRadius: CGFloat
    let lineWidth: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hueShift: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(aiGradient, lineWidth: lineWidth)
                    .opacity(active ? 0.95 : 0.38)
                    .hueRotation(.degrees(hueShift))
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color(red: 0.24, green: 0.66, blue: 1).opacity(active ? 0.28 : 0.12), radius: active ? 16 : 8)
            .shadow(color: Color(red: 1, green: 0.34, blue: 0.42).opacity(active ? 0.18 : 0.08), radius: active ? 14 : 6)
            .onAppear { startHueShift() }
    }

    private var aiGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.36, green: 0.62, blue: 1.0),
                Color(red: 0.25, green: 0.88, blue: 0.95),
                Color(red: 0.98, green: 0.74, blue: 0.24),
                Color(red: 1.0, green: 0.33, blue: 0.45),
                Color(red: 0.72, green: 0.38, blue: 1.0),
                Color(red: 0.36, green: 0.62, blue: 1.0)
            ],
            center: .center
        )
    }

    private func startHueShift() {
        guard !reduceMotion else {
            hueShift = 0
            return
        }
        hueShift = 0
        withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
            hueShift = 360
        }
    }
}

extension View {
    func cfAIGlow(active: Bool = true, cornerRadius: CGFloat = CFTheme.cardRadius, lineWidth: CGFloat = 1.2) -> some View {
        modifier(CFAIGlowModifier(active: active, cornerRadius: cornerRadius, lineWidth: lineWidth))
    }
}
