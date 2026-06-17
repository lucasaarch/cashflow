import SwiftUI

struct CFAmountHeader: View {
    let title: String
    @Binding var amount: Decimal
    var amountColor: Color = CFTheme.textPrimary
    var amountFocus: FocusState<Bool>.Binding?

    @FocusState private var internalFocus: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(CFTheme.textSecondary)

            CurrencyField(amount: $amount, placeholder: "R$ 0,00", style: .hero)
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused(focusBinding)
                .foregroundStyle(amountColor)
        }
    }

    private var focusBinding: FocusState<Bool>.Binding {
        amountFocus ?? $internalFocus
    }
}
