import SwiftUI
import SwiftData

struct AddBillSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    private let editing: Bill?

    @State private var name: String
    @State private var amount: Decimal
    @State private var dueDate: Date
    @State private var note: String
    @State private var categoryID: UUID?
    @State private var accountID: UUID?

    init(editing: Bill? = nil) {
        self.editing = editing
        if let editing {
            _name = State(initialValue: editing.name)
            _amount = State(initialValue: editing.amount)
            _dueDate = State(initialValue: editing.dueDate)
            _note = State(initialValue: editing.note)
            _categoryID = State(initialValue: editing.category?.id)
            _accountID = State(initialValue: editing.account?.id)
        } else {
            _name = State(initialValue: "")
            _amount = State(initialValue: 0)
            _dueDate = State(initialValue: .now)
            _note = State(initialValue: "")
            _categoryID = State(initialValue: nil)
            _accountID = State(initialValue: nil)
        }
    }

    private var isEditing: Bool { editing != nil }

    private var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense }
    }

    private var spendableAccounts: [Account] {
        accounts.filter { $0.kind == .bank || $0.kind == .creditCard }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && amount > 0
            && categoryID != nil
            && accountID != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 560)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar conta" : "Nova conta a pagar",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfGlassSheetChrome()
    }

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    CFGlassSheetAmountHeader(title: "Valor previsto", amount: $amount)

                    CFGlassFormPanel(title: "Identificação") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Nome") {
                                TextField("IPTU, Boleto…", text: $name)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Categoria") { categoryPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Conta") { accountPicker }
                        }
                    }

                    CFGlassFormPanel(title: "Vencimento") {
                        CFGlassLabeledField(label: "Vence em") {
                            DateField(date: $dueDate)
                        }
                    }

                    CFGlassFormPanel(title: "Nota") {
                        TextField("Opcional", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                            .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    @ViewBuilder
    private var categoryPicker: some View {
        CFSelectFieldOptional(
            selection: $categoryID,
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

    @ViewBuilder
    private var accountPicker: some View {
        CFSelectFieldOptional(
            selection: $accountID,
            options: spendableAccounts.map { account in
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

    private var footer: some View {
        CFGlassSheetFooter(
            confirmDisabled: !isValid,
            onCancel: { dismiss() },
            onConfirm: { save(); dismiss() }
        ) {
            if isEditing {
                Button(role: .destructive) {
                    if let editing {
                        BillNotifications.cancel(for: editing)
                        modelContext.delete(editing)
                    }
                    dismiss()
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
                .cfGlassDestructiveButton()
                .help("Excluir conta a pagar")
            }
        }
    }

    private func save() {
        guard isValid,
              let categoryID,
              let accountID,
              let category = expenseCategories.first(where: { $0.id == categoryID }),
              let account = spendableAccounts.first(where: { $0.id == accountID })
        else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDue = Calendar.current.startOfDay(for: dueDate)

        if let editing {
            editing.name = trimmedName
            editing.amount = amount
            editing.dueDate = normalizedDue
            editing.note = trimmedNote
            editing.category = category
            editing.account = account
            BillNotifications.schedule(for: editing)
        } else {
            let bill = Bill(
                name: trimmedName,
                amount: amount,
                dueDate: normalizedDue,
                note: trimmedNote,
                category: category,
                account: account
            )
            modelContext.insert(bill)
            BillNotifications.schedule(for: bill)
        }
    }
}
