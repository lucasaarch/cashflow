import SwiftUI

struct CurrencyField: View {
    @Binding var amount: Decimal
    var placeholder: String = "R$ 0,00"

    @State private var rawText: String = ""

    var body: some View {
        TextField(placeholder, text: $rawText)
            .keyboardType(.decimalPad)
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
