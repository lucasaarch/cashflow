import SwiftUI
import SwiftData

struct AddRecurringIncomeSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    private let editing: RecurringIncome?

    @State private var name: String
    @State private var amount: Decimal
    @State private var dayOfMonth: Int
    @State private var startDate: Date
    @State private var indefinite: Bool
    @State private var monthsCount: Int
    @State private var requiresConfirmation: Bool

    @State private var categoryID: UUID?
    @State private var accountID: UUID?

    init(editing: RecurringIncome? = nil) {
        self.editing = editing
        if let editing {
            _name = State(initialValue: editing.name)
            _amount = State(initialValue: editing.amount)
            _dayOfMonth = State(initialValue: editing.dayOfMonth)
            _startDate = State(initialValue: editing.startDate)
            _indefinite = State(initialValue: editing.endDate == nil)
            let initialMonths: Int
            if let end = editing.endDate {
                let comps = Calendar.current.dateComponents([.month], from: editing.startDate, to: end)
                initialMonths = max(1, (comps.month ?? 0) + 1)
            } else {
                initialMonths = 12
            }
            _monthsCount = State(initialValue: initialMonths)
            _requiresConfirmation = State(initialValue: editing.requiresConfirmation)
            _categoryID = State(initialValue: editing.category?.id)
            _accountID = State(initialValue: editing.account?.id)
        } else {
            _name = State(initialValue: "")
            _amount = State(initialValue: 0)
            _dayOfMonth = State(initialValue: Calendar.current.component(.day, from: .now))
            _startDate = State(initialValue: .now)
            _indefinite = State(initialValue: true)
            _monthsCount = State(initialValue: 12)
            _requiresConfirmation = State(initialValue: true)
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
            && dayOfMonth >= 1 && dayOfMonth <= 31
            && categoryID != nil
            && accountID != nil
    }

    private var sheetHeight: CGFloat {
        var height: CGFloat = 600
        if !indefinite { height += 60 }
        return height
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: sheetHeight)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar renda fixa" : "Nova renda fixa",
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
                    CFGlassSheetAmountHeader(title: "Valor mensal", amount: $amount, amountColor: CFTheme.income)

                    CFGlassFormPanel(title: "Identificação") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Nome") {
                                TextField("Salário, Bolsa…", text: $name)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Categoria") { categoryPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Conta") { accountPicker }
                        }
                    }

                    CFGlassFormPanel(title: "Recebimento") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Dia do mês") {
                                DayOfMonthField(day: $dayOfMonth)
                            }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Começa em") {
                                DateField(date: $startDate)
                            }
                        }
                    }

                    CFGlassFormPanel(title: "Duração") {
                        VStack(spacing: 0) {
                            CFGlassToggleRow(
                                title: "Sem prazo (até eu remover)",
                                isOn: $indefinite
                            )
                            if !indefinite {
                                CFGlassPanelDivider()
                                CFGlassLabeledField(label: "Por") {
                                    Stepper(value: $monthsCount, in: 1...120) {
                                        Text("\(monthsCount) \(monthsCount == 1 ? "mês" : "meses")")
                                            .monospacedDigit()
                                    }
                                    .controlSize(.small)
                                    .tint(CFTheme.accent)
                                }
                            }
                        }
                    }

                    CFGlassFormPanel(title: "Confirmação") {
                        VStack(alignment: .leading, spacing: 8) {
                            CFGlassToggleRow(
                                title: "Confirmar manualmente quando o dinheiro entrar",
                                isOn: $requiresConfirmation
                            )
                            Text(requiresConfirmation
                                 ? "Aparece em \"Contas a receber\" todo mês. Você confirma quando o dinheiro cair na conta."
                                 : "Vira lançamento automático no dia. Bom pra salário em débito automático ou rendas garantidas.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                                .padding(.bottom, CFGlassMetrics.rowVerticalPadding)
                        }
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
        CFGlassSheetFooter(
            confirmDisabled: !isValid,
            onCancel: { dismiss() },
            onConfirm: { save(); dismiss() }
        ) {
            if isEditing {
                Button(role: .destructive) {
                    deleteEditing()
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
                .cfGlassDestructiveButton()
                .help("Excluir renda fixa")
            }
        }
    }

    private func endDateForPersistence() -> Date? {
        guard !indefinite else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: monthsCount - 1, to: startDate)
    }

    private func save() {
        guard isValid,
              let categoryID,
              let accountID,
              let category = incomeCategories.first(where: { $0.id == categoryID }),
              let account = depositAccounts.first(where: { $0.id == accountID })
        else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let endDate = endDateForPersistence()
        let normalizedStart = Calendar.current.startOfDay(for: startDate)

        if let editing {
            let requiresConfirmationChanged = editing.requiresConfirmation != requiresConfirmation
            if requiresConfirmationChanged {
                RecurringIncomeMaterializer.deleteUnrealizedOccurrences(rule: editing, context: modelContext)
            }
            editing.name = trimmedName
            editing.amount = amount
            editing.dayOfMonth = dayOfMonth
            editing.startDate = normalizedStart
            editing.endDate = endDate
            editing.requiresConfirmation = requiresConfirmation
            editing.category = category
            editing.account = account
            if !requiresConfirmationChanged {
                RecurringIncomeMaterializer.syncPending(rule: editing, context: modelContext)
            }
            RecurringIncomeMaterializer.materialize(
                rule: editing,
                horizon: Date.now.addingTimeInterval(RecurringIncomeMaterializer.defaultHorizon),
                context: modelContext
            )
        } else {
            let rule = RecurringIncome(
                name: trimmedName,
                amount: amount,
                dayOfMonth: dayOfMonth,
                startDate: normalizedStart,
                endDate: endDate,
                isPaused: false,
                requiresConfirmation: requiresConfirmation,
                category: category,
                account: account
            )
            modelContext.insert(rule)
            RecurringIncomeMaterializer.materialize(
                rule: rule,
                horizon: Date.now.addingTimeInterval(RecurringIncomeMaterializer.defaultHorizon),
                context: modelContext
            )
        }
    }

    private func deleteEditing() {
        guard let editing else { return }
        RecurringIncomeMaterializer.deleteUnrealizedOccurrences(rule: editing, context: modelContext)
        modelContext.delete(editing)
        dismiss()
    }
}
