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
    @State private var progressMode: ProgressMode
    @State private var manualCurrentAmount: Decimal
    @State private var linkedAccountIDs: Set<UUID>

    private enum ProgressMode: String, CaseIterable, Identifiable {
        case linkedAccounts
        case manual

        var id: String { rawValue }

        var title: String {
            switch self {
            case .linkedAccounts: return "Por contas"
            case .manual: return "Manual"
            }
        }

        var subtitle: String {
            switch self {
            case .linkedAccounts: return "Soma o saldo das contas que você escolher"
            case .manual: return "Você informa quanto já juntou"
            }
        }

        var icon: String {
            switch self {
            case .linkedAccounts: return "building.columns.fill"
            case .manual: return "hand.point.up.left.fill"
            }
        }
    }

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
            _progressMode = State(initialValue: editing.usesManualProgress ? .manual : .linkedAccounts)
            _manualCurrentAmount = State(initialValue: editing.manualCurrentAmount ?? 0)
            _linkedAccountIDs = State(initialValue: Set(editing.linkedAccounts.map(\.id)))
        } else {
            _name = State(initialValue: "")
            _targetAmount = State(initialValue: 0)
            _hasDeadline = State(initialValue: false)
            _deadline = State(initialValue: .now)
            _notes = State(initialValue: "")
            _symbolName = State(initialValue: "flag.fill")
            _colorHex = State(initialValue: "#6366F1")
            _progressMode = State(initialValue: .linkedAccounts)
            _manualCurrentAmount = State(initialValue: 0)
            _linkedAccountIDs = State(initialValue: [])
        }
    }

    private var isEditing: Bool { editing != nil }

    private var linkableAccounts: [Account] {
        accounts.filter { $0.kind == .investment || $0.kind == .bank }
    }

    private var linkedBalancePreview: Decimal {
        linkableAccounts
            .filter { linkedAccountIDs.contains($0.id) }
            .reduce(0) { $0 + $1.currentBalance(considering: transactions) }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && targetAmount > 0
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
        .cfAdaptiveSheetFrame(width: 500, height: 660)
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

                sectionHeader("Como acompanhar o progresso")
                progressModePicker

                switch progressMode {
                case .manual:
                    formGroup {
                        inlineField("Quanto já juntou") {
                            CurrencyField(amount: $manualCurrentAmount, placeholder: "R$ 0,00", style: .compact)
                        }
                    }
                case .linkedAccounts:
                    linkedAccountsSection
                }

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

    private var progressModePicker: some View {
        Grid(horizontalSpacing: 10) {
            GridRow {
                ForEach(ProgressMode.allCases) { mode in
                    progressModeCard(mode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private func progressModeCard(_ mode: ProgressMode) -> some View {
        let isSelected = progressMode == mode

        return Button {
            withAnimation(CFMotion.snappy) { progressMode = mode }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? CFTheme.accent : CFTheme.textSecondary)
                Text(mode.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(CFTheme.textPrimary)
                Text(mode.subtitle)
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? CFTheme.accent.opacity(0.1) : CFTheme.surfaceElevated.opacity(0.38))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? CFTheme.accent.opacity(0.45) : CFTheme.textTertiary.opacity(0.15), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var linkedAccountsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if linkableAccounts.isEmpty {
                formGroup {
                    Text("Cadastre contas bancárias ou de investimento para vincular.")
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                        .padding(12)
                }
            } else {
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

            if let editing {
                Button("Usar saldo atual como valor manual") {
                    manualCurrentAmount = GoalProgressCalculator.currentAmount(
                        for: editing,
                        transactions: transactions
                    )
                    progressMode = .manual
                }
                .font(CFTheme.caption())
                .buttonStyle(.borderless)
                .padding(.horizontal, 4)
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
                    Text(balance.brl)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(CFTheme.textSecondary)
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
        let selectedAccounts = linkableAccounts.filter { linkedAccountIDs.contains($0.id) }
        let normalizedDeadline = hasDeadline ? Calendar.current.startOfDay(for: deadline) : nil

        if let editing {
            editing.name = trimmedName
            editing.targetAmount = targetAmount
            editing.deadline = normalizedDeadline
            editing.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            editing.symbolName = symbolName
            editing.colorHex = colorHex
            editing.linkedAccounts = selectedAccounts
            editing.manualCurrentAmount = progressMode == .manual ? manualCurrentAmount : nil
        } else {
            let goal = FinancialGoal(
                name: trimmedName,
                targetAmount: targetAmount,
                manualCurrentAmount: progressMode == .manual ? manualCurrentAmount : nil,
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
