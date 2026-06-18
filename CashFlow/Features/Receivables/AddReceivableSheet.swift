import SwiftUI
import SwiftData

struct AddReceivableSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    private let editing: Receivable?

    @State private var name: String
    @State private var amount: Decimal
    @State private var expectedDate: Date
    @State private var note: String
    @State private var categoryID: UUID?
    @State private var accountID: UUID?

    init(editing: Receivable? = nil) {
        self.editing = editing
        if let editing {
            _name = State(initialValue: editing.name)
            _amount = State(initialValue: editing.amount)
            _expectedDate = State(initialValue: editing.expectedDate)
            _note = State(initialValue: editing.note)
            _categoryID = State(initialValue: editing.category?.id)
            _accountID = State(initialValue: editing.account?.id)
        } else {
            _name = State(initialValue: "")
            _amount = State(initialValue: 0)
            _expectedDate = State(initialValue: .now)
            _note = State(initialValue: "")
            _categoryID = State(initialValue: nil)
            _accountID = State(initialValue: nil)
        }
    }

    private var isEditing: Bool { editing != nil }

    private var incomeCategories: [Category] {
        categories.filter { $0.kind == .income }
    }

    private var depositAccounts: [Account] {
        accounts.filter { $0.kind != .creditCard }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && amount > 0
            && categoryID != nil
            && accountID != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            CFAmountHeader(title: "Valor previsto", amount: $amount, amountColor: CFTheme.income)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            Divider()
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 540)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar recebível" : "Novo recebível",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section(title: "Identificação") {
                    CFInputField(label: "Nome", text: $name, placeholder: "Salário, Freela…")
                    labeledRow("Categoria") { categoryPicker }
                    labeledRow("Conta") { accountPicker }
                }
                section(title: "Previsão") {
                    labeledRow("Esperado em") {
                        DateField(date: $expectedDate)
                    }
                }
                section(title: "Nota") {
                    TextField("Opcional", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.plain)
                        .font(CFTheme.body())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(CFTheme.surfaceElevated.opacity(0.45))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
    }

    @ViewBuilder
    private var categoryPicker: some View {
        CFSelectFieldOptional(
            selection: $categoryID,
            options: incomeCategories.map { category in
                CFSelectOption(
                    id: category.id,
                    title: category.name,
                    symbolName: category.symbolName,
                    tint: CFTheme.income
                )
            },
            placeholder: "Selecionar"
        )
    }

    @ViewBuilder
    private var accountPicker: some View {
        CFSelectFieldOptional(
            selection: $accountID,
            options: depositAccounts.map { account in
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

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)
            VStack(spacing: 6) {
                content()
            }
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
            if isEditing {
                CFPillButton(title: "Excluir", icon: "trash", iconOnly: true, style: .destructive) {
                    if let editing {
                        ReceivableNotifications.cancel(for: editing)
                        modelContext.delete(editing)
                    }
                    dismiss()
                }
                .help("Excluir recebível")
            }
            Spacer()
            CFPillButton(title: "Cancelar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            CFPillButton(title: "Salvar", style: .primary) {
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

    private func save() {
        guard isValid,
              let categoryID,
              let accountID,
              let category = incomeCategories.first(where: { $0.id == categoryID }),
              let account = depositAccounts.first(where: { $0.id == accountID })
        else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedExpected = Calendar.current.startOfDay(for: expectedDate)

        if let editing {
            editing.name = trimmedName
            editing.amount = amount
            editing.expectedDate = normalizedExpected
            editing.note = trimmedNote
            editing.category = category
            editing.account = account
            ReceivableNotifications.schedule(for: editing)
        } else {
            let receivable = Receivable(
                name: trimmedName,
                amount: amount,
                expectedDate: normalizedExpected,
                note: trimmedNote,
                category: category,
                account: account
            )
            modelContext.insert(receivable)
            ReceivableNotifications.schedule(for: receivable)
        }
    }
}
