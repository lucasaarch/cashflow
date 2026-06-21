import SwiftUI

struct CFAnimatedAmount: View {
    let amount: Decimal
    var font: Font = CFTheme.heroAmount()
    var color: Color = CFTheme.textPrimary
    var prefix: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text("\(prefix)\(amount.brl)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(reduceMotion ? .identity : .numericText())
            .animation(reduceMotion ? nil : CFMotion.gentle, value: amount)
    }
}
