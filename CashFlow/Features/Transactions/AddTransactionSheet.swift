import SwiftUI
import SwiftData

struct AddTransactionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var aiService: AIService

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    private let editing: Transaction?

    @State private var draft: TransactionDraft
    @State private var showingNote: Bool
    @State private var naturalLanguageInput = ""
    @State private var isParsingNL = false
    @State private var categorySuggestion: Category?
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
        .cfSheetBackground()
        .tint(CFTheme.accent)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            CFAmountHeader(
                title: "Valor do lançamento",
                amount: $draft.amount,
                amountColor: amountColor,
                amountFocus: $amountFocused
            )

            TransactionKindSwitcher(kind: $draft.kind, namespace: switcherNamespace)
                .frame(maxWidth: 260)
                .onChange(of: draft.kind) { _, _ in
                    if let current = draft.category,
                       current.kind != (draft.kind == .income ? .income : .expense) {
                        draft.category = nil
                    }
                    categorySuggestion = nil
                }

            if aiService.configuration.isReady {
                HStack(spacing: 8) {
                    TextField("Ex: gastei 45 no mercado ontem", text: $naturalLanguageInput)
                        .textFieldStyle(.plain)
                        .font(CFTheme.body())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .cfFieldChrome(isFocused: false)
                    Button {
                        Task { await applyNaturalLanguage() }
                    } label: {
                        Image(systemName: isParsingNL ? "hourglass" : "wand.and.stars")
                    }
                    .buttonStyle(.plain)
                    .disabled(naturalLanguageInput.trimmingCharacters(in: .whitespaces).isEmpty || isParsingNL)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
    }

    private var amountColor: Color {
        draft.kind == .expense ? CFTheme.textPrimary : CFTheme.accent
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                fieldSection(title: "Detalhes") {
                    labeledRow("Categoria") {
                        VStack(alignment: .trailing, spacing: 6) {
                            categoryPicker
                            if draft.category == nil, draft.amount > 0, aiService.configuration.isReady {
                                Button("Sugerir categoria") {
                                    Task { await suggestCategory() }
                                }
                                .buttonStyle(.borderless)
                                .font(CFTheme.caption())
                            }
                            if let categorySuggestion, draft.category == nil {
                                Button("Usar \(categorySuggestion.name)") {
                                    draft.category = categorySuggestion
                                    self.categorySuggestion = nil
                                }
                                .buttonStyle(.borderless)
                                .font(CFTheme.caption())
                            }
                        }
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
    private var categoryPicker: some View {
        CFSelectFieldOptional(
            selection: categorySelectionID,
            options: filteredCategories.map { category in
                CFSelectOption(
                    id: category.id,
                    title: category.name,
                    symbolName: category.symbolName,
                    tint: draft.kind == .expense ? CFTheme.expense : CFTheme.accent
                )
            }
        )
    }

    @ViewBuilder
    private var accountPicker: some View {
        CFSelectFieldOptional(
            selection: accountSelectionID,
            options: accounts.map { account in
                CFSelectOption(
                    id: account.id,
                    title: account.name,
                    symbolName: account.symbolName,
                    tint: Color(hex: account.colorHex)
                )
            }
        )
    }

    private var categorySelectionID: Binding<UUID?> {
        Binding(
            get: { draft.category?.id },
            set: { newID in
                draft.category = filteredCategories.first { $0.id == newID }
            }
        )
    }

    private var accountSelectionID: Binding<UUID?> {
        Binding(
            get: { draft.account?.id },
            set: { newID in
                draft.account = accounts.first { $0.id == newID }
            }
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 10) {
            CFPillButton(
                title: showingNote ? "Ocultar nota" : "Adicionar nota",
                icon: showingNote ? "text.bubble.fill" : "text.bubble",
                iconOnly: true,
                style: .ghost
            ) {
                withAnimation(CFMotion.snappy) {
                    showingNote.toggle()
                }
            }
            .help(showingNote ? "Ocultar nota" : "Adicionar nota")

            if showingNote {
                CFPillButton(title: "Limpar nota", icon: "xmark.circle", iconOnly: true, style: .ghost) {
                    draft.note = ""
                }
                .help("Limpar nota")
            }

            if isEditing {
                CFPillButton(title: "Excluir", icon: "trash", iconOnly: true, style: .destructive) {
                    deleteEditing()
                }
                .help("Excluir lançamento")
            }

            Spacer()

            CFPillButton(title: "Cancelar", style: .ghost) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            CFPillButton(title: "Salvar", style: .primary) {
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

    private func applyNaturalLanguage() async {
        guard aiService.configuration.isReady else { return }
        isParsingNL = true
        defer { isParsingNL = false }
        do {
            let parsed = try await AICategorizeService.parseTransaction(
                text: naturalLanguageInput,
                aiService: aiService
            )
            if let amount = parsed.amount { draft.amount = amount }
            if let kind = parsed.kind { draft.kind = kind }
            if let date = parsed.date { draft.occurredOn = date }
            if let note = parsed.note { draft.note = note; showingNote = true }
            if let categoryName = parsed.categoryName {
                draft.category = filteredCategories.first {
                    $0.name.localizedCaseInsensitiveContains(categoryName)
                }
            }
            if let accountName = parsed.accountName {
                draft.account = accounts.first {
                    $0.name.localizedCaseInsensitiveContains(accountName)
                }
            }
            naturalLanguageInput = ""
        } catch {
            // Silent fail — user can still fill manually
        }
    }

    private func suggestCategory() async {
        guard aiService.configuration.isReady else { return }
        do {
            let suggestion = try await AICategorizeService.suggestCategory(
                amount: draft.amount,
                kind: draft.kind,
                note: draft.note,
                categories: categories,
                aiService: aiService
            )
            guard let uuid = UUID(uuidString: suggestion.categoryId),
                  let category = filteredCategories.first(where: { $0.id == uuid }) else { return }
            if suggestion.confidence >= 0.8 {
                draft.category = category
            } else {
                categorySuggestion = category
            }
        } catch {
            categorySuggestion = nil
        }
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
