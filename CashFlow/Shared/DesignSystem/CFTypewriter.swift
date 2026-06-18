import SwiftUI

/// Reveals text character-by-character. When `markdown` is true, the reveal phase
/// shows plain text (stripped of markers); once complete, the view swaps to
/// `CFMarkdownText` for proper rendering. Honors `accessibilityReduceMotion`.
struct CFTypewriter: View {
    let text: String
    var markdown: Bool = false
    var animated: Bool = true
    var charactersPerSecond: Double = 110
    var onProgress: ((Int) -> Void)? = nil
    var onComplete: (() -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedCount: Int = 0
    @State private var caretVisible: Bool = true
    @State private var isComplete: Bool = false

    var body: some View {
        Group {
            if shouldAnimate && !isComplete {
                Text(animatedContent)
            } else if markdown {
                CFMarkdownText(text: text)
            } else {
                Text(text)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .task(id: text) { await runReveal() }
        .task(id: text) { await runCaret() }
    }

    private var shouldAnimate: Bool { animated && !reduceMotion }

    private var plainText: String {
        markdown ? text.cfStrippingMarkdown() : text
    }

    private var animatedContent: AttributedString {
        let count = min(revealedCount, plainText.count)
        let endIndex = plainText.index(plainText.startIndex, offsetBy: count)
        var attr = AttributedString(plainText[..<endIndex])
        var caret = AttributedString(caretVisible ? "▍" : " ")
        caret.foregroundColor = CFTheme.accent.opacity(0.8)
        attr.append(caret)
        return attr
    }

    private func runReveal() async {
        guard shouldAnimate else {
            revealedCount = plainText.count
            isComplete = true
            onProgress?(revealedCount)
            onComplete?()
            return
        }
        isComplete = false
        revealedCount = 0
        let total = plainText.count
        let tick = max(UInt64(1_000_000_000 / charactersPerSecond), 1)
        while revealedCount < total {
            try? await Task.sleep(nanoseconds: tick)
            if Task.isCancelled { return }
            revealedCount = min(revealedCount + 1, total)
            if revealedCount == total || revealedCount.isMultiple(of: 8) {
                onProgress?(revealedCount)
            }
        }
        isComplete = true
        onComplete?()
    }

    private func runCaret() async {
        guard shouldAnimate else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            caretVisible.toggle()
        }
    }
}
