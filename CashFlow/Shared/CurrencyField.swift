import SwiftUI

enum CurrencyFieldStyle {
    case form
    case hero
    case compact
}

struct CurrencyField: View {
    @Binding var amount: Decimal
    var placeholder: String = "R$ 0,00"
    var style: CurrencyFieldStyle = .form

    @State private var rawText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $rawText)
            .textFieldStyle(.plain)
            .focused($isFocused)
#if os(iOS)
            .keyboardType(.decimalPad)
#endif
            .modifier(CurrencyFieldChrome(style: style, isFocused: isFocused))
            .onAppear {
                if amount > 0 {
                    rawText = formatted(amount)
                }
            }
            .onChange(of: rawText) { _, newValue in
                amount = parse(newValue)
            }
    }

    private func parse(_ text: String) -> Decimal {
        let digitsOnly = text.filter { $0.isNumber }
        guard let cents = Int(digitsOnly) else { return 0 }
        return Decimal(cents) / 100
    }

    private func formatted(_ value: Decimal) -> String {
        value.brl
    }
}

private struct CurrencyFieldChrome: ViewModifier {
    let style: CurrencyFieldStyle
    let isFocused: Bool

    func body(content: Content) -> some View {
        switch style {
        case .hero:
            content
        case .compact:
            content
                .font(CFTheme.body())
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .fixedSize(horizontal: true, vertical: false)
                .cfCompactFieldChrome(isFocused: isFocused)
        case .form:
            content
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cfFieldChrome(isFocused: isFocused)
        }
    }
}
