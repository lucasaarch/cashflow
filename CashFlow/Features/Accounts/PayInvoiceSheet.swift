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
            CFAmountHeader(title: "Valor do pagamento", amount: $amount)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            Divider()
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 420)
        .cfCompactSheetToolbar(
            title: "Pagar fatura",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
        .onAppear(perform: prefillDefaults)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section(title: "Origem") {
                    labeledRow("Conta") {
                        bankPicker
                    }
                    labeledRow("Categoria") {
                        categoryPicker
                    }
                    labeledRow("Data") {
                        DateField(date: $paymentDate)
                    }
                }

                Text("Será registrada uma saída na conta bancária e uma entrada no cartão \(card.name).")
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
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

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textSecondary)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.38))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            CFPillButton(title: "Cancelar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            CFPillButton(title: "Confirmar", style: .primary) {
                save()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .opacity(isValid ? 1 : 0.5)
            .allowsHitTesting(isValid)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
