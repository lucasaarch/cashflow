import SwiftUI

#if DEBUG

#Preview("Design System — Light") {
    @Previewable @State var text = "Mercado"
    @Previewable @State var amount: Decimal = 577.15
    @Previewable @State var date = Date.now
    @Previewable @State var closingDay = 5
    @Previewable @State var kind = TransactionKind.expense
    @Previewable @State var color = Color(hex: "#8B5CF6")
    @Previewable @State var symbol = "cart.fill"
    @Previewable @State var categoryKind = CategoryKind.expense
    @Previewable @Namespace var previewNamespace

    ScrollView {
        VStack(alignment: .leading, spacing: 28) {
            previewSection("Botões") {
                HStack(spacing: 10) {
                    CFPillButton(title: "Salvar", style: .primary) {}
                    CFPillButton(title: "Cancelar", style: .ghost) {}
                    CFPillButton(title: "Excluir", icon: "trash", style: .destructive) {}
                    CFPillButton(title: "Nota", icon: "text.bubble", iconOnly: true, style: .ghost) {}
                }
            }

            previewSection("Badges e métricas") {
                HStack(spacing: 16) {
                    CFIconBadge(symbolName: "cart.fill", tint: CFTheme.expense, size: 34)
                    CFIconBadge(symbolName: "creditcard.fill", tint: CFTheme.debt, size: 34)
                    CFStatChip(label: "Saiu no mês", amount: 250.35, tint: CFTheme.expense, icon: "arrow.up.right")
                }
            }

            previewSection("Campos") {
                VStack(alignment: .leading, spacing: 12) {
                    CFInputField(label: "Nome", text: $text, placeholder: "Banco Inter…")
                    CFAmountHeader(title: "Saldo inicial", amount: $amount)
                    HStack(spacing: 12) {
                        DateField(date: $date)
                        DayOfMonthField(day: $closingDay)
                    }
                    CurrencyField(amount: $amount, placeholder: "R$ 0,00", style: .form)
                        .font(.title3)
                }
            }

            previewSection("Pickers") {
                VStack(alignment: .leading, spacing: 12) {
                    CFSelectField(selection: $categoryKind, options: CategoryKind.selectOptions)
                    TransactionKindSwitcher(kind: $kind, namespace: previewNamespace)
                        .frame(maxWidth: 260)
                    IconPickerField(symbolName: $symbol, tint: CFTheme.expense)
                    ColorPickerField(color: $color)
                }
            }

            previewSection("Cards") {
                CFPanel {
                    CFPanelSection(title: "Maiores dores", subtitle: "Onde o dinheiro está indo") {
                        CFProgressBar(progress: 0.72, color: CFTheme.expense, height: 8)
                        CFAnimatedAmount(amount: 187.45, font: CFTheme.kpiValue(), color: CFTheme.textPrimary)
                    }
                }
            }

            previewSection("Lista") {
                CFHoverRow {
                    HStack {
                        CFIconBadge(symbolName: "cart.fill", tint: CFTheme.expense, size: 30)
                        Text("Mercado")
                        Spacer()
                        Text("R$ 187,45").monospacedDigit()
                    }
                }
            }

            previewSection("Empty state") {
                CFEmptyState(
                    symbol: "wallet.pass",
                    title: "Nenhuma conta",
                    message: "Cadastre contas para começar.",
                    actionTitle: "Criar conta"
                ) {}
                .frame(height: 260)
            }
        }
        .padding(24)
    }
    .cfPageBackground()
    .previewCashFlow(width: 960, height: 1200)
    .preferredColorScheme(.light)
}

#Preview("Design System — Dark") {
    @Previewable @State var text = "Mercado"
    @Previewable @State var amount: Decimal = 577.15
    @Previewable @State var date = Date.now
    @Previewable @State var closingDay = 5
    @Previewable @State var kind = TransactionKind.expense
    @Previewable @State var color = Color(hex: "#8B5CF6")
    @Previewable @State var symbol = "cart.fill"
    @Previewable @State var categoryKind = CategoryKind.expense
    @Previewable @Namespace var previewNamespace

    ScrollView {
        VStack(alignment: .leading, spacing: 28) {
            previewSection("Botões") {
                HStack(spacing: 10) {
                    CFPillButton(title: "Salvar", style: .primary) {}
                    CFPillButton(title: "Cancelar", style: .ghost) {}
                }
            }
            previewSection("Campos") {
                CFInputField(label: "Nome", text: $text, placeholder: "Banco Inter…")
                CFAmountHeader(title: "Saldo inicial", amount: $amount)
            }
            previewSection("Pickers") {
                CFSelectField(selection: $categoryKind, options: CategoryKind.selectOptions)
                TransactionKindSwitcher(kind: $kind, namespace: previewNamespace)
                    .frame(maxWidth: 260)
            }
        }
        .padding(24)
    }
    .cfPageBackground()
    .previewCashFlow(width: 960, height: 700)
    .preferredColorScheme(.dark)
}

@ViewBuilder
private func previewSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 12) {
        Text(title.uppercased())
            .font(CFTheme.caption())
            .foregroundStyle(CFTheme.textSecondary)
        content()
    }
}

#endif
