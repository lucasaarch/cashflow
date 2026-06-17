import SwiftUI
import SwiftData

struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    private let editing: Transaction?

    @State private var draft: TransactionDraft
    @State private var showingNote: Bool
    @FocusState private var amountFocused: Bool
    @Namespace private var switcherNamespace

    private let defaults = UserDefaults.standard

    init(editing: Transaction? = nil) {
        self.editing = editing
        if let editing {
            _draft = State(initialValue: TransactionDraft(from: editing))
            _showingNote = State(initialValue: !editing.note.isEmpty)
        } else {
            _draft = State(initialValue: TransactionDraft())
            _showingNote = State(initialValue: false)
        }
    }

    private var isEditing: Bool { editing != nil }

    var filteredCategories: [Category] {
        categories.filter { $0.kind == (draft.kind == .income ? .income : .expense) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 440, height: showingNote ? 500 : 440)
        .onAppear(perform: prefillDefaults)
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Text(isEditing ? "Editar lançamento" : "Novo lançamento")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            CurrencyField(amount: $draft.amount, placeholder: "R$ 0,00")
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($amountFocused)
                .foregroundStyle(amountColor)

            TransactionKindSwitcher(kind: $draft.kind, namespace: switcherNamespace)
                .frame(maxWidth: 260)
                .onChange(of: draft.kind) { _, _ in
                    if let current = draft.category,
                       current.kind != (draft.kind == .income ? .income : .expense) {
                        draft.category = nil
                    }
                }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
    }

    private var amountColor: Color {
        draft.kind == .expense ? CFTheme.textPrimary : CFTheme.income
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                fieldSection(title: "Detalhes") {
                    labeledRow("Categoria") {
                        categoryPicker
                    }
                    labeledRow("Conta") {
                        accountPicker
                    }
                    labeledRow("Data") {
                        DateField(date: $draft.occurredOn)
                    }
                }

                if showingNote {
                    fieldSection(title: "Nota") {
                        TextField("Nota", text: $draft.note, axis: .vertical)
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
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.never)
    }

    private func fieldSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
            VStack(spacing: 8) {
                content()
            }
        }
    }

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
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

    @ViewBuilder
    private var categorySelectionLabel: some View {
        HStack(spacing: 6) {
            if let category = draft.category {
                Image(systemName: category.symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(draft.kind == .expense ? CFTheme.expense : CFTheme.income)
                Text(category.name)
                    .foregroundStyle(CFTheme.textPrimary)
            } else {
                Text("Selecionar")
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(CFTheme.textTertiary)
        }
    }

    @ViewBuilder
    private var accountSelectionLabel: some View {
        HStack(spacing: 6) {
            if let account = draft.account {
                Image(systemName: account.symbolName)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color(hex: account.colorHex))
                Text(account.name)
                    .foregroundStyle(CFTheme.textPrimary)
            } else {
                Text("Selecionar")
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(CFTheme.textTertiary)
        }
    }

    private func pickerLabel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(CFTheme.body())
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(CFTheme.surfaceSecondary.opacity(0.8))
            )
    }

    // MARK: - Pickers

    private var categoryPicker: some View {
        Menu {
            ForEach(filteredCategories) { category in
                Button {
                    draft.category = category
                } label: {
                    Label(category.name, systemImage: category.symbolName)
                }
            }
        } label: {
            pickerLabel {
                categorySelectionLabel
            }
        }
        .menuStyle(.borderlessButton)
    }

    private var accountPicker: some View {
        Menu {
            ForEach(accounts) { account in
                Button {
                    draft.account = account
                } label: {
                    Label(account.name, systemImage: account.symbolName)
                }
            }
        } label: {
            pickerLabel {
                accountSelectionLabel
            }
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            CFPillButton(
                title: showingNote ? "Ocultar nota" : "Adicionar nota",
                icon: showingNote ? "text.bubble.fill" : "text.bubble",
                style: .ghost
            ) {
                withAnimation(CFMotion.snappy) {
                    showingNote.toggle()
                }
            }
            .help(showingNote ? "Ocultar nota" : "Adicionar nota")

            if showingNote {
                CFPillButton(title: "Limpar", icon: "xmark.circle", style: .ghost) {
                    draft.note = ""
                }
                .help("Limpar nota")
            }

            if isEditing {
                CFPillButton(title: "Excluir", icon: "trash", style: .destructive) {
                    deleteEditing()
                }
                .help("Excluir lançamento")
            }

            Spacer()

            CFPillButton(title: "Cancelar", style: .ghost) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            if !isEditing {
                CFPillButton(title: "Salvar e adicionar", icon: "plus", style: .ghost) {
                    save(closeAfter: false)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .sheetButtonDisabled(!draft.isValid)
            }

            CFPillButton(title: "Salvar", icon: "checkmark", style: .primary) {
                save(closeAfter: true)
            }
            .keyboardShortcut(.defaultAction)
            .sheetButtonDisabled(!draft.isValid)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Logic

    private func prefillDefaults() {
        // Skip defaults when editing — draft is already loaded from the source transaction.
        if !isEditing {
            if draft.account == nil,
               let stored = defaults.string(forKey: UserDefaultsKeys.lastUsedAccountID),
               let uuid = UUID(uuidString: stored),
               let match = accounts.first(where: { $0.id == uuid }) {
                draft.account = match
            }
            if draft.account == nil {
                draft.account = accounts.first
            }

            if draft.category == nil,
               let stored = defaults.string(forKey: UserDefaultsKeys.lastUsedCategoryID),
               let uuid = UUID(uuidString: stored),
               let match = categories.first(where: { $0.id == uuid && $0.kind == (draft.kind == .income ? .income : .expense) }) {
                draft.category = match
            }
        }

        amountFocused = true
    }

    private func save(closeAfter: Bool) {
        guard draft.isValid else { return }

        if let editing {
            editing.amount = draft.amount
            editing.kind = draft.kind
            editing.occurredOn = draft.occurredOn
            editing.note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.category = draft.category
            editing.account = draft.account
        } else {
            let transaction = Transaction(
                amount: draft.amount,
                kind: draft.kind,
                occurredOn: draft.occurredOn,
                note: draft.note.trimmingCharacters(in: .whitespacesAndNewlines),
                category: draft.category,
                account: draft.account
            )
            modelContext.insert(transaction)
        }

        if let accountID = draft.account?.id {
            defaults.set(accountID.uuidString, forKey: UserDefaultsKeys.lastUsedAccountID)
        }
        if let categoryID = draft.category?.id {
            defaults.set(categoryID.uuidString, forKey: UserDefaultsKeys.lastUsedCategoryID)
        }

        if closeAfter {
            dismiss()
        } else {
            draft.resetForNextEntry()
            amountFocused = true
        }
    }

    private func deleteEditing() {
        if let editing {
            modelContext.delete(editing)
        }
        dismiss()
    }
}

private extension View {
    func sheetButtonDisabled(_ disabled: Bool) -> some View {
        opacity(disabled ? 0.5 : 1)
            .allowsHitTesting(!disabled)
    }
}

struct TransactionDraft {
    var amount: Decimal = 0
    var kind: TransactionKind = .expense
    var occurredOn: Date = .now
    var note: String = ""
    var category: Category?
    var account: Account?

    init() {}

    init(from transaction: Transaction) {
        self.amount = transaction.amount
        self.kind = transaction.kind
        self.occurredOn = transaction.occurredOn
        self.note = transaction.note
        self.category = transaction.category
        self.account = transaction.account
    }

    var isValid: Bool {
        amount > 0 && account != nil && category != nil
    }

    mutating func resetForNextEntry() {
        amount = 0
        note = ""
    }
}
