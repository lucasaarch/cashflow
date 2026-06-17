import SwiftUI

enum CFMotion {
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let bouncy = Animation.spring(response: 0.50, dampingFraction: 0.70)
    static let gentle = Animation.spring(response: 0.60, dampingFraction: 0.90)

    static func staggerDelay(index: Int, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : Double(index) * 0.05
    }

    static func animation(_ preset: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : preset
    }
}

struct CFStaggerAppear: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                let delay = CFMotion.staggerDelay(index: index, reduceMotion: reduceMotion)
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(CFMotion.bouncy.delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func cfStaggerAppear(index: Int) -> some View {
        modifier(CFStaggerAppear(index: index))
    }
}
