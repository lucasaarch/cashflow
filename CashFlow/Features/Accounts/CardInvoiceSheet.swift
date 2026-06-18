import SwiftUI
import SwiftData

struct CardInvoiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var privacy: PrivacyMode
    @Query private var transactions: [Transaction]

    let account: Account

    @State private var showingPayment = false

    private var statement: CreditCardStatement {
        account.openStatement(considering: transactions)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 520, height: sheetHeight)
        .cfCompactSheetToolbar(
            title: "Fatura do cartão",
            cancelTitle: "Fechar",
            saveTitle: "Pagar fatura",
            saveDisabled: statement.totalDebt <= 0,
            onCancel: { dismiss() },
            onSave: { showingPayment = true }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
        .sheet(isPresented: $showingPayment) {
            PayInvoiceSheet(card: account, maxAmount: statement.totalDebt)
        }
    }

    private var sheetHeight: CGFloat {
        statement.isEmpty ? 320 : min(560, 280 + CGFloat(statement.items.count) * 52)
    }

    private var header: some View {
        HStack(spacing: 12) {
            CFIconBadge(
                symbolName: account.symbolName,
                tint: Color(hex: account.colorHex),
                size: 36
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(account.name)
                    .font(CFTheme.headline())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(headerSubtitle)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("A pagar")
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                CFAnimatedAmount(
                    amount: statement.totalDebt,
                    font: .title3.monospacedDigit().weight(.semibold),
                    color: statement.totalDebt > 0 ? CFTheme.debt : CFTheme.textPrimary
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var headerSubtitle: String {
        if statement.hasBillingCycle,
           let closing = statement.closingDate,
           let due = statement.dueDate {
            let closingText = closing.formatted(.dateTime.day().month(.abbreviated).locale(Money.locale))
            let dueText = due.formatted(.dateTime.day().month(.abbreviated).locale(Money.locale))
            return "Fecha \(closingText) · Vence \(dueText)"
        }
        if account.hasBillingCycle {
            return account.billingCycleCaption ?? "Cartão"
        }
        return "Configure fechamento e vencimento para ver o ciclo da fatura"
    }

    @ViewBuilder
    private var content: some View {
        if statement.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(CFTheme.income)
                Text("Nada a pagar")
                    .font(CFTheme.headline())
                    .foregroundStyle(CFTheme.textPrimary)
                Text("Esta fatura está zerada.")
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(20)
        } else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(statement.items) { item in
                        CFHoverRow {
                            lineRow(item)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.never)
        }
    }

    private func lineRow(_ item: CreditCardStatementLine) -> some View {
        HStack(spacing: 12) {
            switch item {
            case .openingBalance:
                CFIconBadge(symbolName: "clock.arrow.circlepath", tint: CFTheme.textSecondary, size: 28)
            case .expense(let transaction):
                CFIconBadge(
                    symbolName: transaction.category?.symbolName ?? "arrow.up.right",
                    tint: CFTheme.expense,
                    size: 28
                )
            case .payment:
                CFIconBadge(symbolName: "arrow.down.left", tint: CFTheme.income, size: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(lineTitle(item))
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(lineSubtitle(item))
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }

            Spacer()

            Text(lineAmount(item))
                .font(CFTheme.body().weight(.medium))
                .monospacedDigit()
                .foregroundStyle(lineAmountColor(item))
        }
    }

    private func lineTitle(_ item: CreditCardStatementLine) -> String {
        switch item {
        case .openingBalance:
            return "Saldo anterior"
        case .expense(let transaction):
            return transaction.category?.name ?? "Despesa"
        case .payment:
            return "Pagamento"
        }
    }

    private func lineSubtitle(_ item: CreditCardStatementLine) -> String {
        switch item {
        case .openingBalance:
            return "Dívida antes dos lançamentos deste ciclo"
        case .expense(let transaction), .payment(let transaction):
            return transaction.occurredOn.formatted(.dateTime.day().month(.abbreviated).locale(Money.locale))
        }
    }

    private func lineAmount(_ item: CreditCardStatementLine) -> String {
        switch item {
        case .openingBalance(let amount):
            return amount.brl(masked: privacy.valuesHidden)
        case .expense(let transaction):
            return transaction.amount.brl(masked: privacy.valuesHidden)
        case .payment(let transaction):
            return "−\(transaction.amount.brl(masked: privacy.valuesHidden))"
        }
    }

    private func lineAmountColor(_ item: CreditCardStatementLine) -> Color {
        switch item {
        case .openingBalance, .expense:
            return CFTheme.textPrimary
        case .payment:
            return CFTheme.income
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            CFPillButton(title: "Fechar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            if statement.totalDebt > 0 {
                CFPillButton(title: "Pagar fatura", style: .primary) {
                    showingPayment = true
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
