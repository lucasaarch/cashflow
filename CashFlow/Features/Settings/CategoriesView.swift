import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif
    @Query(sort: [SortDescriptor(\Category.sortOrder)]) private var categories: [Category]

    @State private var showingAdd = false
    @State private var editingCategory: Category?
    #if os(macOS)
    @State private var highlightedCategoryID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif

    var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense && !$0.isArchived }
    }

    var incomeCategories: [Category] {
        categories.filter { $0.kind == .income && !$0.isArchived }
    }

    var archivedCategories: [Category] {
        categories.filter { $0.isArchived }
    }

    private var sectionCount: Int {
        var count = 0
        if !expenseCategories.isEmpty { count += 1 }
        if !incomeCategories.isEmpty { count += 1 }
        return count
    }

    var body: some View {
        Group {
            if categories.isEmpty {
                emptyState
            } else {
                categoryList
            }
        }
        .navigationTitle("Categorias")
        .detailToolbarAdd(help: "Nova categoria") {
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            CategorySheet()
        }
        .sheet(item: $editingCategory) { category in
            CategorySheet(editing: category)
        }
        .cfGlassDetailChrome()
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "tag",
            title: "Nenhuma categoria",
            message: "Crie categorias para classificar seus gastos e receitas (ex: Mercado, Delivery, Salário).",
            actionTitle: "Criar primeira categoria"
        ) {
            showingAdd = true
        }
    }

    private var categoryList: some View {
        ScrollViewReader { proxy in
            CFGlassPage {
                CFGlassPageStack {
                    if !expenseCategories.isEmpty {
                        categorySection(
                            title: "Despesas",
                            items: expenseCategories,
                            tint: CFTheme.expense,
                            staggerIndex: 0
                        )
                    }

                    if !incomeCategories.isEmpty {
                        categorySection(
                            title: "Receitas",
                            items: incomeCategories,
                            tint: CFTheme.income,
                            staggerIndex: expenseCategories.isEmpty ? 0 : 1
                        )
                    }

                    if !archivedCategories.isEmpty {
                        CFGlassArchiveSection(
                            title: "Arquivadas",
                            staggerIndex: sectionCount,
                            items: archivedCategories,
                            systemName: { $0.symbolName },
                            itemTitle: { $0.name }
                        ) { category in
                            category.isArchived = false
                        }
                    }
                }
            }
            #if os(macOS)
            .spotlightScrollTarget(
                navigation: spotlightNavigation,
                kind: .category,
                highlightedID: $highlightedCategoryID,
                focusTask: $spotlightFocusTask,
                proxy: proxy,
                onReveal: { id in
                    if let category = categories.first(where: { $0.id == id }) {
                        editingCategory = category
                    }
                }
            )
            #endif
        }
    }

    private func categorySection(
        title: String,
        items: [Category],
        tint: Color,
        staggerIndex: Int
    ) -> some View {
        CFGlassSection(title: title, staggerIndex: staggerIndex) {
            CFGlassEnumeratedPanel(items: items) { category, _ in
                CFGlassRowButton {
                    editingCategory = category
                } label: {
                    CFGlassChevronRow(
                        systemName: category.symbolName,
                        tint: tint,
                        title: category.name
                    )
                }
                .id(category.id)
                #if os(macOS)
                .spotlightFocused(highlightedCategoryID == category.id)
                #endif
                .contextMenu {
                    Button {
                        editingCategory = category
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        category.isArchived = true
                    } label: {
                        Label("Arquivar", systemImage: "archivebox")
                    }
                }
            }
        }
    }
}

private struct CategorySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [Category]

    private let editing: Category?

    @State private var name: String
    @State private var symbolName: String
    @State private var kind: CategoryKind
    @State private var budgetAmount: Decimal

    init(editing: Category? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _symbolName = State(initialValue: editing?.symbolName ?? "tag.fill")
        _kind = State(initialValue: editing?.kind ?? .expense)
        _budgetAmount = State(initialValue: editing?.monthlyBudget ?? 0)
    }

    private var isEditing: Bool { editing != nil }
    private var hasUsage: Bool { (editing?.transactions.count ?? 0) > 0 }

    private var accentColor: Color {
        kind == .expense ? CFTheme.expense : CFTheme.accent
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 350)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar categoria" : "Nova categoria",
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
                    CFGlassFormPanel(title: "Identificação") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Nome") {
                                TextField("Mercado, Delivery, Salário…", text: $name)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }

                            if kind == .expense {
                                CFGlassPanelDivider()
                                CFGlassLabeledField(label: "Teto mensal (opcional)") {
                                    CurrencyField(amount: $budgetAmount, placeholder: "R$ 0,00", style: .compact)
                                }
                                Text("Limite de gasto nesta categoria no mês. Aparece na Visão geral quando preenchido.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                                    .padding(.bottom, CFGlassMetrics.rowVerticalPadding)
                            }

                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Tipo") {
                                CFSelectField(
                                    selection: $kind,
                                    options: CategoryKind.selectOptions,
                                    disabled: hasUsage
                                )
                            }
                        }
                    }

                    if hasUsage {
                        Text("Tipo bloqueado: há lançamentos usando essa categoria. Arquive e crie uma nova se precisar mudar.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }

                    CFGlassFormPanel(title: "Aparência") {
                        CFGlassLabeledField(label: "Ícone") {
                            IconPickerField(symbolName: $symbolName, tint: accentColor)
                        }
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
            content()
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
            confirmDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty,
            onCancel: { dismiss() },
            onConfirm: { save(); dismiss() }
        ) {
            if isEditing {
                Button(role: .destructive) {
                    archive()
                } label: {
                    Label("Arquivar", systemImage: "archivebox")
                }
                .cfGlassDestructiveButton()
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalSymbol = symbolName.isEmpty ? "tag.fill" : symbolName
        let budget = parsedBudget()

        if let editing {
            editing.name = trimmedName
            editing.symbolName = finalSymbol
            if !hasUsage {
                editing.kind = kind
            }
            if kind == .expense {
                editing.monthlyBudget = budget
            } else {
                editing.monthlyBudget = nil
            }
        } else {
            let nextSort = (categories.filter { $0.kind == kind }.map(\.sortOrder).max() ?? -1) + 1
            let category = Category(
                name: trimmedName,
                symbolName: finalSymbol,
                kind: kind,
                sortOrder: nextSort,
                monthlyBudgetMinorUnits: budget?.minorUnits
            )
            modelContext.insert(category)
        }
    }

    private func parsedBudget() -> Decimal? {
        guard kind == .expense, budgetAmount > 0 else { return nil }
        return budgetAmount
    }

    private func archive() {
        editing?.isArchived = true
        dismiss()
    }
}

#if DEBUG
#Preview("Sheet — Nova categoria") {
    CategorySheet()
        .previewSheet(width: 440, height: 380)
}

#Preview("Sheet — Editar categoria") {
    CategorySheet(editing: PreviewData.marketCategory)
        .previewSheet(width: 440, height: 380)
}
#endif
