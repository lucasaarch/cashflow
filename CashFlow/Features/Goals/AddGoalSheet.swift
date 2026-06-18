import SwiftUI
import SwiftData

struct AddGoalSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    private let editing: FinancialGoal?

    @State private var name: String
    @State private var targetAmount: Decimal
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var notes: String
    @State private var symbolName: String
    @State private var colorHex: String
    @State private var linkedAccountIDs: Set<UUID>
    @State private var createsDedicatedAccount: Bool
    @State private var dedicatedOpeningBalance: Decimal

    init(editing: FinancialGoal? = nil) {
        self.editing = editing
        if let editing {
            _name = State(initialValue: editing.name)
            _targetAmount = State(initialValue: editing.targetAmount)
            _hasDeadline = State(initialValue: editing.deadline != nil)
            _deadline = State(initialValue: editing.deadline ?? .now)
            _notes = State(initialValue: editing.notes)
            _symbolName = State(initialValue: editing.symbolName)
            _colorHex = State(initialValue: editing.colorHex)
            _linkedAccountIDs = State(initialValue: Set(editing.linkedAccounts.map(\.id)))
            _createsDedicatedAccount = State(initialValue: false)
            _dedicatedOpeningBalance = State(initialValue: 0)
        } else {
            _name = State(initialValue: "")
            _targetAmount = State(initialValue: 0)
            _hasDeadline = State(initialValue: false)
            _deadline = State(initialValue: .now)
            _notes = State(initialValue: "")
            _symbolName = State(initialValue: "flag.fill")
            _colorHex = State(initialValue: "#6366F1")
            _linkedAccountIDs = State(initialValue: [])
            _createsDedicatedAccount = State(initialValue: true)
            _dedicatedOpeningBalance = State(initialValue: 0)
        }
    }

    private var isEditing: Bool { editing != nil }

    /// Anything that holds positive money can back a goal — banks, investments and other goal accounts.
    private var linkableAccounts: [Account] {
        accounts.filter { $0.kind != .creditCard }
    }

    private var linkedBalancePreview: Decimal {
        linkableAccounts
            .filter { linkedAccountIDs.contains($0.id) }
            .reduce(0) { $0 + $1.currentBalance(considering: transactions) }
    }

    private var hasProgressSource: Bool {
        createsDedicatedAccount || !linkedAccountIDs.isEmpty
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && targetAmount > 0
            && hasProgressSource
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
        .cfAdaptiveSheetFrame(width: 500, height: 720)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar meta" : "Nova meta",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
    }

    private var header: some View {
        VStack(spacing: 14) {
            CFAmountHeader(title: "Valor da meta", amount: $targetAmount)
            CFInputField(label: "Nome da meta", text: $name, placeholder: "Reserva, Viagem, Aposentadoria…")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Aparência")
                formGroup {
                    HStack(spacing: 12) {
                        appearanceField(title: "Ícone") {
                            IconPickerField(symbolName: $symbolName, tint: Color(hex: colorHex))
                        }
                        appearanceField(title: "Cor") {
                            ColorPickerField(color: Binding(
                                get: { Color(hex: colorHex) },
                                set: { colorHex = $0.hexString }
                            ))
                        }
                    }
                    .padding(12)
                }

                sectionHeader("Prazo")
                formGroup {
                    toggleRow("Definir data limite", isOn: $hasDeadline)
                    if hasDeadline {
                        formDivider
                        inlineField("Concluir até") {
                            DateField(date: $deadline)
                        }
                    }
                }

                sectionHeader("De onde vem o dinheiro")
                if !isEditing {
                    dedicatedAccountSection
                }
                linkedAccountsSection

                sectionHeader("Nota")
                formGroup {
                    TextField("Opcional — motivação, lembrete…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.plain)
                        .font(CFTheme.body())
                        .padding(12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .scrollIndicators(.never)
    }

    private var dedicatedAccountSection: some View {
        formGroup {
            toggleRow("Criar conta dedicada pra essa meta", isOn: $createsDedicatedAccount)
            if createsDedicatedAccount {
                formDivider
                inlineField("Já tem reservado") {
                    CurrencyField(amount: $dedicatedOpeningBalance, placeholder: "R$ 0,00", style: .compact)
                }
                Text("Vamos criar uma conta tipo \"Meta\" separada, fora do disponível e fora dos investimentos. Você deposita nela quando guardar dinheiro pra esse objetivo.")
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }

    private var linkedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !createsDedicatedAccount && linkableAccounts.isEmpty {
                formGroup {
                    Text("Cadastre uma conta bancária, de investimento ou crie uma conta dedicada pra essa meta.")
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                        .padding(12)
                }
            } else if !linkableAccounts.isEmpty {
                Text(createsDedicatedAccount ? "Vincular contas existentes (opcional)" : "Vincular contas existentes")
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textTertiary)
                    .padding(.horizontal, 2)

                formGroup {
                    ForEach(Array(linkableAccounts.enumerated()), id: \.element.id) { index, account in
                        if index > 0 { formDivider }
                        accountRow(account)
                    }
                }

                if !linkedAccountIDs.isEmpty {
                    HStack {
                        Text("Total vinculado")
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                        Spacer()
                        Text(linkedBalancePreview.brl)
                            .font(.callout.weight(.semibold).monospacedDigit())
                            .foregroundStyle(CFTheme.accent)
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func accountRow(_ account: Account) -> some View {
        let isLinked = linkedAccountIDs.contains(account.id)
        let balance = account.currentBalance(considering: transactions)

        return Button {
            withAnimation(CFMotion.snappy) {
                if isLinked { linkedAccountIDs.remove(account.id) }
                else { linkedAccountIDs.insert(account.id) }
            }
        } label: {
            HStack(spacing: 10) {
                CFIconBadge(
                    symbolName: account.symbolName,
                    tint: Color(hex: account.colorHex),
                    size: 28
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(account.name)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(CFTheme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(account.kind.displayName)
                            .font(.caption2)
                            .foregroundStyle(CFTheme.textTertiary)
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(CFTheme.textTertiary)
                        Text(balance.brl)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(CFTheme.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isLinked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isLinked ? CFTheme.accent : CFTheme.textTertiary.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Form chrome

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(CFTheme.caption().weight(.semibold))
            .foregroundStyle(CFTheme.textSecondary)
            .textCase(.uppercase)
            .padding(.horizontal, 2)
    }

    private func formGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.38))
        )
    }

    private var formDivider: some View {
        Divider().padding(.leading, 12)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textPrimary)
        }
        .toggleStyle(.switch)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func inlineField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textSecondary)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func appearanceField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if isEditing {
                CFPillButton(title: "Excluir", icon: "trash", iconOnly: true, style: .destructive) {
                    if let editing { modelContext.delete(editing) }
                    dismiss()
                }
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
        guard isValid else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let normalizedDeadline = hasDeadline ? Calendar.current.startOfDay(for: deadline) : nil

        var selectedAccounts = linkableAccounts.filter { linkedAccountIDs.contains($0.id) }

        if !isEditing, createsDedicatedAccount {
            let nextSortOrder = (accounts.map(\.sortOrder).max() ?? -1) + 1
            let dedicated = Account(
                name: trimmedName,
                kind: .goal,
                colorHex: colorHex,
                symbolName: symbolName,
                sortOrder: nextSortOrder,
                openingBalance: dedicatedOpeningBalance,
                openingDate: Calendar.current.startOfDay(for: .now)
            )
            modelContext.insert(dedicated)
            selectedAccounts.append(dedicated)
        }

        if let editing {
            editing.name = trimmedName
            editing.targetAmount = targetAmount
            editing.deadline = normalizedDeadline
            editing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.symbolName = symbolName
            editing.colorHex = colorHex
            editing.linkedAccounts = selectedAccounts
            editing.manualCurrentAmount = nil
        } else {
            let goal = FinancialGoal(
                name: trimmedName,
                targetAmount: targetAmount,
                deadline: normalizedDeadline,
                symbolName: symbolName,
                colorHex: colorHex,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                linkedAccounts: selectedAccounts
            )
            modelContext.insert(goal)
        }
    }
}
