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
            header
            Divider()
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
        .cfSheetBackground()
        .tint(CFTheme.accent)
    }

    private var sheetHeight: CGFloat {
        var height: CGFloat = 440
        if showingNote { height += 60 }
        if showsInstallmentSection { height += 70 }
        if editingInstallment != nil { height += 60 }
        return height
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            CFAmountHeader(
                title: "Valor do lançamento",
                amount: $draft.amount,
                amountColor: amountColor
            )

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
        draft.kind == .expense ? CFTheme.textPrimary : CFTheme.accent
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

                if showsInstallmentSection {
                    fieldSection(title: "Parcelar") {
                        labeledRow("Parcelas") {
                            Stepper(
                                value: $installmentCount,
                                in: 1...24
                            ) {
                                Text(installmentCount == 1 ? "À vista" : "\(installmentCount)x")
                                    .font(CFTheme.body())
                                    .monospacedDigit()
                            }
                            .controlSize(.small)
                        }
                        if installmentCount > 1 {
                            Text(installmentSummary)
                                .font(CFTheme.caption())
                                .foregroundStyle(CFTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                    }
                }

                if let plan = editingInstallment {
                    installmentBanner(plan: plan)
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

    private func installmentBanner(plan: InstallmentPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.fill")
                    .font(.caption)
                    .foregroundStyle(CFTheme.accent)
                Text("Parcela \(editing?.installmentIndex ?? 0) de \(plan.installmentCount)")
                    .font(CFTheme.body().weight(.medium))
                    .foregroundStyle(CFTheme.textPrimary)
                Spacer()
            }
            Text("Editar afeta apenas esta parcela. Para mudar todas, exclua o plano inteiro e cadastre de novo.")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
            CFPillButton(title: "Excluir plano inteiro", icon: "trash", style: .destructive) {
                confirmingDeletePlan = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CFTheme.accent.opacity(0.08))
        )
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
            options: spendableAccounts.map { account in
                CFSelectOption(
                    id: account.id,
                    title: account.name,
                    symbolName: account.symbolName,
                    tint: Color(hex: account.colorHex)
                )
            }
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
