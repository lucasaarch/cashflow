import SwiftUI

struct MonthlyIncomeEditor: View {
    @Binding var cents: Int
    @State private var amount: Decimal = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Orçamento mensal")
                .font(.headline)
            Text("Quanto você espera ter disponível este mês (salário + outras entradas previstas).")
                .font(.caption)
                .foregroundStyle(CFTheme.textSecondary)
            CurrencyField(amount: $amount, placeholder: "R$ 0,00", style: .form)
                .font(.title3)
            if cents > 0 {
                Button(role: .destructive) {
                    amount = 0
                    cents = 0
                } label: {
                    Label("Remover orçamento", systemImage: "xmark.circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(16)
        .onAppear { amount = Decimal(cents) / 100 }
        .onChange(of: amount) { _, newValue in
            cents = NSDecimalNumber(decimal: newValue * 100).intValue
        }
    }
}
