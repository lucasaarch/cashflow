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
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            Text(isEditing ? "Editar lançamento" : "Novo lançamento")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            CurrencyField(amount: $draft.amount, placeholder: "R$ 0,00")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
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
        draft.amount > 0 ? (draft.kind == .expense ? .red : .green) : .secondary
    }

    // MARK: - Form

    private var formContent: some View {
        Form {
            Section {
                LabeledContent("Categoria") {
                    categoryPicker
                }
                LabeledContent("Conta") {
                    accountPicker
                }
                LabeledContent("Data") {
                    DateField(date: $draft.occurredOn)
                }
            }

            if showingNote {
                Section {
                    TextField("Nota", text: $draft.note, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

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
            HStack(spacing: 6) {
                if let category = draft.category {
                    Image(systemName: category.symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(draft.kind == .expense ? Color.red : .green)
                    Text(category.name)
                } else {
                    Text("Selecionar")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
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
            HStack(spacing: 6) {
                if let account = draft.account {
                    Image(systemName: account.symbolName)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(hex: account.colorHex))
                    Text(account.name)
                } else {
                    Text("Selecionar")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showingNote.toggle()
                }
            } label: {
                Label(showingNote ? "Ocultar nota" : "Adicionar nota",
                      systemImage: showingNote ? "text.bubble.fill" : "text.bubble")
                    .labelStyle(.iconOnly)
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .help(showingNote ? "Ocultar nota" : "Adicionar nota")

            if isEditing {
                Button(role: .destructive) {
                    deleteEditing()
                } label: {
                    Label("Excluir", systemImage: "trash")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help("Excluir lançamento")
            }

            Spacer()

            Button("Cancelar") { dismiss() }
                .keyboardShortcut(.cancelAction)

            if !isEditing {
                Button {
                    save(closeAfter: false)
                } label: {
                    Text("Salvar e adicionar")
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!draft.isValid)
            }

            Button("Salvar") {
                save(closeAfter: true)
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!draft.isValid)
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
