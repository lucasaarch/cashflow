import SwiftUI
import SwiftData

struct AddWishlistItemSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Category> { !$0.isArchived },
           sort: [SortDescriptor(\Category.sortOrder)])
    private var categories: [Category]

    private let editing: WishlistItem?

    @State private var name: String
    @State private var amount: Decimal
    @State private var priority: WishlistPriority
    @State private var note: String
    @State private var hasDesiredBy: Bool
    @State private var desiredBy: Date
    @State private var categoryID: UUID?

    init(editing: WishlistItem? = nil) {
        self.editing = editing
        if let editing {
            _name = State(initialValue: editing.name)
            _amount = State(initialValue: editing.estimatedAmount)
            _priority = State(initialValue: editing.priority)
            _note = State(initialValue: editing.note)
            _hasDesiredBy = State(initialValue: editing.desiredBy != nil)
            _desiredBy = State(initialValue: editing.desiredBy ?? .now)
            _categoryID = State(initialValue: editing.category?.id)
        } else {
            _name = State(initialValue: "")
            _amount = State(initialValue: 0)
            _priority = State(initialValue: .medium)
            _note = State(initialValue: "")
            _hasDesiredBy = State(initialValue: false)
            _desiredBy = State(initialValue: .now)
            _categoryID = State(initialValue: nil)
        }
    }

    private var isEditing: Bool { editing != nil }

    private var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 560)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar desejo" : "Novo desejo",
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
                    CFGlassSheetAmountHeader(title: "Valor estimado", amount: $amount, amountColor: CFTheme.expense)

                    CFGlassFormPanel(title: "Identificação") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Nome") {
                                TextField("Fone, calça nova…", text: $name)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Prioridade") { priorityPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Categoria") { categoryPicker }
                        }
                    }

                    CFGlassFormPanel(title: "Prazo") {
                        VStack(spacing: 0) {
                            CFGlassToggleRow(title: "Data desejada", isOn: $hasDesiredBy)
                            if hasDesiredBy {
                                CFGlassPanelDivider()
                                CFGlassLabeledField(label: "Desejo até") {
                                    DateField(date: $desiredBy)
                                }
                            }
                        }
                    }

                    CFGlassFormPanel(title: "Notas") {
                        TextField("Link da loja, modelo, promoção…", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                            .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    @ViewBuilder
    private var priorityPicker: some View {
        CFSelectField(selection: $priority, options: WishlistPriority.selectOptions)
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
            placeholder: "Opcional"
        )
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    if let editing {
                        modelContext.delete(editing)
                    }
                    dismiss()
                } label: {
                    Label("Excluir", systemImage: "trash")
                }
                .cfGlassDestructiveButton()
                .help("Excluir desejo")
            }
        }
    }

    private func save() {
        guard isValid else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let category = categoryID.flatMap { id in expenseCategories.first(where: { $0.id == id }) }
        let normalizedDesired = hasDesiredBy ? Calendar.current.startOfDay(for: desiredBy) : nil

        if let editing {
            editing.name = trimmedName
            editing.estimatedAmount = amount
            editing.priority = priority
            editing.note = trimmedNote
            editing.desiredBy = normalizedDesired
            editing.category = category
        } else {
            let item = WishlistItem(
                name: trimmedName,
                estimatedAmount: amount,
                priority: priority,
                note: trimmedNote,
                desiredBy: normalizedDesired,
                category: category
            )
            modelContext.insert(item)
        }
    }
}
