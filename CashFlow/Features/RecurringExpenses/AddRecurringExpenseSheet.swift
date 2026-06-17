import SwiftUI
import SwiftData

struct AddRecurringExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    private let editing: RecurringExpense?

    @State private var name: String
    @State private var amount: Decimal
    @State private var dayOfMonth: Int
    @State private var startDate: Date
    @State private var indefinite: Bool
    @State private var monthsCount: Int
    @State private var requiresConfirmation: Bool

    @State private var categoryID: UUID?
    @State private var accountID: UUID?

    init(editing: RecurringExpense? = nil) {
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
            _requiresConfirmation = State(initialValue: false)
            _categoryID = State(initialValue: nil)
            _accountID = State(initialValue: nil)
        }
    }

    private var isEditing: Bool { editing != nil }

    private var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense }
    }

    private var spendableAccounts: [Account] {
        accounts.filter { $0.kind != .investment }
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
            CFAmountHeader(title: "Valor mensal", amount: $amount)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)
            Divider()
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: sheetHeight)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar despesa fixa" : "Nova despesa fixa",
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
                    CFInputField(label: "Nome", text: $name, placeholder: "Netflix, Aluguel…")
                    labeledRow("Categoria") { categoryPicker }
                    labeledRow("Conta") { accountPicker }
                }

                section(title: "Cobrança") {
                    labeledRow("Dia do mês") {
                        DayOfMonthField(day: $dayOfMonth)
                    }
                    labeledRow("Começa em") {
                        DateField(date: $startDate)
                    }
                }

                section(title: "Duração") {
                    Toggle("Sem prazo (até eu remover)", isOn: $indefinite)
                        .toggleStyle(.switch)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    if !indefinite {
                        labeledRow("Por") {
                            Stepper(value: $monthsCount, in: 1...120) {
                                Text("\(monthsCount) \(monthsCount == 1 ? "mês" : "meses")")
                                    .font(CFTheme.body())
                                    .monospacedDigit()
                            }
                            .controlSize(.small)
                        }
                    }
                }

                section(title: "Confirmação") {
                    Toggle("Precisa confirmação manual ao pagar", isOn: $requiresConfirmation)
                        .toggleStyle(.switch)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    Text(requiresConfirmation
                         ? "Aparece em \"Contas a pagar\" todo mês. Você confirma o pagamento quando ele acontecer."
                         : "Vira lançamento automático no dia. Bom pra débito automático ou cobrança no cartão.")
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 6)
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
                    deleteEditing()
                }
                .help("Excluir despesa fixa")
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

    private func endDateForPersistence() -> Date? {
        guard !indefinite else { return nil }
        let calendar = Calendar.current
        return calendar.date(byAdding: .month, value: monthsCount - 1, to: startDate)
    }

    private func save() {
        guard isValid,
              let categoryID,
              let accountID,
              let category = expenseCategories.first(where: { $0.id == categoryID }),
              let account = spendableAccounts.first(where: { $0.id == accountID })
        else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let endDate = endDateForPersistence()
        let normalizedStart = Calendar.current.startOfDay(for: startDate)

        if let editing {
            // Editing a rule: nuke unrealized future occurrences and rebuild from new params.
            RecurringExpenseMaterializer.deleteUnrealizedOccurrences(rule: editing, context: modelContext)
            editing.name = trimmedName
            editing.amount = amount
            editing.dayOfMonth = dayOfMonth
            editing.startDate = normalizedStart
            editing.endDate = endDate
            editing.requiresConfirmation = requiresConfirmation
            editing.category = category
            editing.account = account
            RecurringExpenseMaterializer.materialize(
                rule: editing,
                horizon: Date.now.addingTimeInterval(RecurringExpenseMaterializer.defaultHorizon),
                context: modelContext
            )
        } else {
            let rule = RecurringExpense(
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
            RecurringExpenseMaterializer.materialize(
                rule: rule,
                horizon: Date.now.addingTimeInterval(RecurringExpenseMaterializer.defaultHorizon),
                context: modelContext
            )
        }
    }

    private func deleteEditing() {
        guard let editing else { return }
        // "Soft" delete: keep past history, drop future and the rule.
        RecurringExpenseMaterializer.deleteUnrealizedOccurrences(rule: editing, context: modelContext)
        modelContext.delete(editing)
        dismiss()
    }
}
