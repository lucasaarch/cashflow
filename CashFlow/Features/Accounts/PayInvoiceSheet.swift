import SwiftUI
import SwiftData

struct PayInvoiceSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    let card: Account
    let maxAmount: Decimal
    let linkedBill: Bill?

    @State private var amount: Decimal
    @State private var paymentDate = Date.now
    @State private var bankAccountID: UUID?
    @State private var expenseCategoryID: UUID?

    init(card: Account, maxAmount: Decimal, linkedBill: Bill? = nil) {
        self.card = card
        self.maxAmount = maxAmount
        self.linkedBill = linkedBill
        _amount = State(initialValue: maxAmount)
    }

    private var bankAccounts: [Account] {
        accounts.filter { $0.kind == .bank }
    }

    private var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense }
    }

    private var isValid: Bool {
        amount > 0
            && amount <= maxAmount
            && bankAccountID != nil
            && expenseCategoryID != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 460)
        .cfCompactSheetToolbar(
            title: "Pagar fatura",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfGlassSheetChrome()
        .onAppear(perform: prefillDefaults)
    }

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    CFGlassSheetAmountHeader(title: "Valor do pagamento", amount: $amount)

                    CFGlassFormPanel(title: "Origem") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Conta") { bankPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Categoria") { categoryPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Data") {
                                DateField(date: $paymentDate)
                            }
                        }
                    }

                    Text("Será registrada uma saída na conta bancária e uma entrada no cartão \(card.name).")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    @ViewBuilder
    private var bankPicker: some View {
        CFSelectFieldOptional(
            selection: $bankAccountID,
            options: bankAccounts.map { account in
                CFSelectOption(
                    id: account.id,
                    title: account.name,
                    symbolName: account.symbolName,
                    tint: Color(hex: account.colorHex)
                )
            },
            placeholder: "Selecionar"
        )
    }

    @ViewBuilder
    private var categoryPicker: some View {
        CFSelectFieldOptional(
            selection: $expenseCategoryID,
            options: expenseCategories.map { category in
                CFSelectOption(
                    id: category.id,
                    title: category.name,
                    symbolName: category.symbolName,
                    tint: CFTheme.expense
                )
            },
            placeholder: "Selecionar"
        )
    }

    private var footer: some View {
        CFGlassSheetFooter(
            confirmTitle: "Confirmar",
            confirmDisabled: !isValid,
            onCancel: { dismiss() },
            onConfirm: { save(); dismiss() }
        )
    }

    private func prefillDefaults() {
        if bankAccountID == nil {
            bankAccountID = bankAccounts.first?.id
        }
        if expenseCategoryID == nil {
            expenseCategoryID = expenseCategories.first?.id
        }
    }

    private func save() {
        guard isValid,
              let bankAccountID,
              let expenseCategoryID,
              let bankAccount = bankAccounts.first(where: { $0.id == bankAccountID }),
              let expenseCategory = expenseCategories.first(where: { $0.id == expenseCategoryID }) else {
            return
        }

        let note = "Pagamento fatura \(card.name)"
        let normalizedDate = Calendar.current.startOfDay(for: paymentDate)

        let bankPayment = Transaction(
            amount: amount,
            kind: .expense,
            occurredOn: normalizedDate,
            note: note,
            category: expenseCategory,
            account: bankAccount
        )
        let cardPayment = Transaction(
            amount: amount,
            kind: .income,
            occurredOn: normalizedDate,
            note: note,
            account: card
        )

        modelContext.insert(bankPayment)
        modelContext.insert(cardPayment)

        if let linkedBill {
            linkedBill.status = .paid
            linkedBill.paidOn = normalizedDate
            linkedBill.paidTransactionID = bankPayment.id
            BillNotifications.cancel(for: linkedBill)
        }
    }
}
