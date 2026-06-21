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
    @State private var installmentCount: Int = 1
    @State private var confirmingDeletePlan: Bool = false
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
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 440, height: sheetHeight)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar lançamento" : "Novo lançamento",
            saveDisabled: !draft.isValid,
            onCancel: { dismiss() },
            onSave: { save(closeAfter: true) }
        )
        .cfAdaptiveSheetDetents()
        .onAppear(perform: prefillDefaults)
        .cfGlassSheetChrome()
    }

    private var sheetHeight: CGFloat {
        var height: CGFloat = 440
        if showingNote { height += 60 }
        if showsInstallmentSection { height += 70 }
        if editingInstallment != nil { height += 60 }
        return height
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    CFGlassPanel(glass: .regular.tint(CFTheme.accent.opacity(0.06))) {
                        VStack(spacing: 12) {
                            CFAmountHeader(
                                title: "Valor do lançamento",
                                amount: $draft.amount,
                                amountColor: amountColor
                            )
                            TransactionKindSwitcher(kind: $draft.kind, namespace: switcherNamespace)
                                .frame(maxWidth: 260)
                                .frame(maxWidth: .infinity)
                                .onChange(of: draft.kind) { _, _ in
                                    if let current = draft.category,
                                       current.kind != (draft.kind == .income ? .income : .expense) {
                                        draft.category = nil
                                    }
                                }
                        }
                        .padding(18)
                    }

                    CFGlassFormPanel(title: "Detalhes") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Categoria") { categoryPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Conta") { accountPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Data") {
                                DateField(date: $draft.occurredOn)
                            }
                        }
                    }

                    if showsInstallmentSection {
                        CFGlassFormPanel(title: "Parcelar") {
                            VStack(spacing: 0) {
                                CFGlassLabeledField(label: "Parcelas") {
                                    Stepper(value: $installmentCount, in: 1...24) {
                                        Text(installmentCount == 1 ? "À vista" : "\(installmentCount)x")
                                            .monospacedDigit()
                                    }
                                    .controlSize(.small)
                                    .tint(CFTheme.accent)
                                }
                                if installmentCount > 1 {
                                    Text(installmentSummary)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                                        .padding(.bottom, CFGlassMetrics.rowVerticalPadding)
                                }
                            }
                        }
                    }

                    if let plan = editingInstallment {
                        installmentBanner(plan: plan)
                    }

                    if showingNote {
                        CFGlassFormPanel(title: "Nota") {
                            TextField("Nota", text: $draft.note, axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.plain)
                                .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                                .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
                        }
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    private var showsInstallmentSection: Bool {
        !isEditing
            && draft.kind == .expense
            && draft.account?.kind == .creditCard
    }

    private var editingInstallment: InstallmentPlan? {
        editing?.installmentPlan
    }

    private var installmentSummary: String {
        let total = draft.amount
        guard total > 0, installmentCount > 1 else { return "" }
        let per = (total / Decimal(installmentCount)).brl
        let calendar = Calendar.current
        let firstReporting = draft.account.flatMap {
            Transaction(amount: total, kind: .expense, occurredOn: draft.occurredOn, account: $0)
                .reportingDate(calendar: calendar)
        } ?? draft.occurredOn
        let lastDate = calendar.date(byAdding: .month, value: installmentCount - 1, to: firstReporting) ?? firstReporting
        let formatter = Date.FormatStyle.dateTime.month(.abbreviated).year(.twoDigits).locale(Money.locale)
        let firstText = firstReporting.formatted(formatter)
        let lastText = lastDate.formatted(formatter)
        return "\(installmentCount)x de \(per) · 1ª: \(firstText) · última: \(lastText)"
    }

    private var amountColor: Color {
        draft.kind == .expense ? CFTheme.textPrimary : CFTheme.accent
    }

    private func installmentBanner(plan: InstallmentPlan) -> some View {
        CFGlassPanel(glass: .regular.tint(CFTheme.accent.opacity(0.08))) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.caption)
                        .foregroundStyle(CFTheme.accent)
                    Text("Parcela \(editing?.installmentIndex ?? 0) de \(plan.installmentCount)")
                        .font(.body.weight(.medium))
                    Spacer()
                }
                Text("Editar afeta apenas esta parcela. Para mudar todas, exclua o plano inteiro e cadastre de novo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button(role: .destructive) {
                    confirmingDeletePlan = true
                } label: {
                    Label("Excluir plano inteiro", systemImage: "trash")
                }
                .cfGlassDestructiveButton()
            }
            .padding(14)
        }
        .confirmationDialog(
            "Excluir todas as \(plan.installmentCount) parcelas deste plano?",
            isPresented: $confirmingDeletePlan,
            titleVisibility: .visible
        ) {
            Button("Excluir plano", role: .destructive) {
                deletePlan(plan)
            }
            Button("Cancelar", role: .cancel) {}
        }
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
            },
            searchable: true,
            searchPlaceholder: "Buscar categoria…"
        )
    }

    @ViewBuilder
    private var accountPicker: some View {
        CFSelectFieldOptional(
            selection: accountSelectionID,
            options: spendableAccounts.map { account in
                CFSelectOption(
                    id: account.id,
                    title: account.name,
                    symbolName: account.symbolName,
                    tint: Color(hex: account.colorHex)
                )
            },
            searchable: true,
            searchPlaceholder: "Buscar conta…"
        )
    }

    private var spendableAccounts: [Account] {
        accounts.filter { $0.kind != .investment }
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
                draft.account = spendableAccounts.first { $0.id == newID }
            }
        )
    }

    // MARK: - Footer

    private var footer: some View {
        CFGlassSheetFooter(
            confirmDisabled: !draft.isValid,
            onCancel: { dismiss() },
            onConfirm: { save(closeAfter: true) }
        ) {
            Button {
                withAnimation(CFMotion.snappy) {
                    showingNote.toggle()
                }
            } label: {
                Label(
                    showingNote ? "Ocultar nota" : "Adicionar nota",
                    systemImage: showingNote ? "text.bubble.fill" : "text.bubble"
                )
            }
            .cfGlassSecondaryButton()
            .help(showingNote ? "Ocultar nota" : "Adicionar nota")

            if showingNote {
                Button {
                    draft.note = ""
                } label: {
                    Label("Limpar nota", systemImage: "xmark.circle")
                }
                .cfGlassSecondaryButton()
                .help("Limpar nota")
            }

            if isEditing {
                Button(role: .destructive) {
                    deleteEditing()
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
                .cfGlassDestructiveButton()
                .help("Excluir lançamento")
            }
        }
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
        } else if showsInstallmentSection, installmentCount > 1, let account = draft.account {
            insertInstallmentPlan(account: account)
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
        }
    }

    private func insertInstallmentPlan(account: Account) {
        let noteBase = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let totalCents = NSDecimalNumber(decimal: draft.amount * 100).intValue
        guard totalCents > 0 else { return }

        let plan = InstallmentPlan(
            purchaseDate: draft.occurredOn,
            totalAmount: draft.amount,
            installmentCount: installmentCount,
            note: noteBase,
            account: account,
            category: draft.category
        )
        modelContext.insert(plan)

        let drafts = InstallmentMaterializer.drafts(
            purchaseDate: draft.occurredOn,
            totalCents: totalCents,
            installmentCount: installmentCount,
            noteBase: noteBase
        )

        for d in drafts {
            let txn = Transaction(
                amount: d.amount,
                kind: .expense,
                occurredOn: d.occurredOn,
                note: d.note,
                category: draft.category,
                account: account,
                installmentPlan: plan,
                installmentIndex: d.installmentIndex
            )
            modelContext.insert(txn)
        }
    }

    private func deletePlan(_ plan: InstallmentPlan) {
        modelContext.delete(plan)
        dismiss()
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
