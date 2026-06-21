import SwiftUI

enum CFMotion {
    static let quick = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let bouncy = Animation.spring(response: 0.50, dampingFraction: 0.70)
    static let gentle = Animation.spring(response: 0.60, dampingFraction: 0.90)

    static func staggerDelay(index: Int, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : Double(index) * 0.05
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

    func cfStreamSettleReveal(isActive: Bool, onFinished: (() -> Void)? = nil) -> some View {
        modifier(CFStreamSettleReveal(isActive: isActive, onFinished: onFinished))
    }
}

/// Soft fade/slide when streamed assistant text settles into final markdown.
struct CFStreamSettleReveal: ViewModifier {
    let isActive: Bool
    var onFinished: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .offset(y: offsetY)
            .blur(radius: blur)
            .onAppear { beginIfNeeded() }
            .onChange(of: isActive) { _, active in
                if active { beginIfNeeded() }
            }
    }

    private var opacity: Double {
        guard isActive, !settled else { return 1 }
        return reduceMotion ? 1 : 0.55
    }

    private var offsetY: CGFloat {
        guard isActive, !settled else { return 0 }
        return reduceMotion ? 0 : 5
    }

    private var blur: CGFloat {
        guard isActive, !settled, !reduceMotion else { return 0 }
        return 0.6
    }

    private func beginIfNeeded() {
        guard isActive, !settled else { return }
        if reduceMotion {
            settled = true
            onFinished?()
            return
        }
        withAnimation(CFMotion.gentle) {
            settled = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            onFinished?()
        }
    }
}
