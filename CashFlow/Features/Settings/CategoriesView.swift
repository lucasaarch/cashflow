import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Category.sortOrder)]) private var categories: [Category]

    @State private var showingAdd = false
    @State private var editingCategory: Category?

    var expenseCategories: [Category] {
        categories.filter { $0.kind == .expense && !$0.isArchived }
    }

    var incomeCategories: [Category] {
        categories.filter { $0.kind == .income && !$0.isArchived }
    }

    var archivedCategories: [Category] {
        categories.filter { $0.isArchived }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Nova categoria", systemImage: "plus")
                }
                .help("Nova categoria")
            }
        }
        .sheet(isPresented: $showingAdd) {
            CategorySheet()
        }
        .sheet(item: $editingCategory) { category in
            CategorySheet(editing: category)
        }
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !expenseCategories.isEmpty {
                    categorySection(title: "Despesas", items: expenseCategories, tint: CFTheme.expense)
                }

                if !incomeCategories.isEmpty {
                    categorySection(title: "Receitas", items: incomeCategories, tint: CFTheme.income)
                }

                if !archivedCategories.isEmpty {
                    archivedSection
                }
            }
            .padding(20)
        }
        .cfPageBackground()
    }

    private func categorySection(title: String, items: [Category], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(items) { category in
                CFHoverRow {
                    categoryRowContent(category, tint: tint)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingCategory = category
                }
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

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arquivadas")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(archivedCategories) { category in
                CFHoverRow {
                    HStack(spacing: 12) {
                        CFIconBadge(symbolName: category.symbolName, tint: CFTheme.textSecondary, size: 28)
                        Text(category.name)
                            .font(CFTheme.body())
                            .foregroundStyle(CFTheme.textSecondary)
                        Spacer()
                        Button("Restaurar") {
                            category.isArchived = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func categoryRowContent(_ category: Category, tint: Color) -> some View {
        HStack(spacing: 12) {
            CFIconBadge(symbolName: category.symbolName, tint: tint, size: 30)
            Text(category.name)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textTertiary)
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

    init(editing: Category? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _symbolName = State(initialValue: editing?.symbolName ?? "tag.fill")
        _kind = State(initialValue: editing?.kind ?? .expense)
    }

    private var isEditing: Bool { editing != nil }
    private var hasUsage: Bool { (editing?.transactions.count ?? 0) > 0 }

    private var accentColor: Color {
        kind == .expense ? CFTheme.expense : CFTheme.income
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 480, height: 460)
        .presentationBackground(.ultraThinMaterial)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            CFIconBadge(
                symbolName: symbolName.isEmpty ? "tag.fill" : symbolName,
                tint: accentColor,
                size: 64
            )
            .shadow(color: accentColor.opacity(0.18), radius: 12, x: 0, y: 6)

            VStack(spacing: 3) {
                Text(name.isEmpty ? (isEditing ? "Sem nome" : "Nova categoria") : name)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(name.isEmpty ? CFTheme.textSecondary : CFTheme.textPrimary)
                    .lineLimit(1)
                Text(kind == .expense ? "Despesa" : "Receita")
                    .font(.subheadline)
                    .foregroundStyle(CFTheme.textSecondary)
            }
        }
        .padding(.top, 26)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section(title: "Identificação") {
                    CFInputField(
                        label: "Nome",
                        text: $name,
                        placeholder: "Mercado, Delivery, Salário…"
                    )

                    labeledRow("Tipo") {
                        Picker("Tipo", selection: $kind) {
                            Text("Despesa").tag(CategoryKind.expense)
                            Text("Receita").tag(CategoryKind.income)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .disabled(hasUsage)
                    }
                }

                if hasUsage {
                    Text("Tipo bloqueado: há lançamentos usando essa categoria. Arquive e crie uma nova se precisar mudar.")
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                }

                section(title: "Aparência") {
                    labeledRow("Ícone") {
                        IconPickerField(symbolName: $symbolName, tint: accentColor)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
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
        HStack(spacing: 10) {
            if isEditing {
                CFPillButton(title: "Arquivar", icon: "archivebox", style: .destructive) {
                    archive()
                }
            }
            Spacer()
            CFPillButton(title: "Cancelar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            CFPillButton(title: "Salvar", icon: "checkmark", style: .primary) {
                save()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .allowsHitTesting(!name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalSymbol = symbolName.isEmpty ? "tag.fill" : symbolName

        if let editing {
            editing.name = trimmedName
            editing.symbolName = finalSymbol
            if !hasUsage {
                editing.kind = kind
            }
        } else {
            let nextSort = (categories.filter { $0.kind == kind }.map(\.sortOrder).max() ?? -1) + 1
            let category = Category(
                name: trimmedName,
                symbolName: finalSymbol,
                kind: kind,
                sortOrder: nextSort
            )
            modelContext.insert(category)
        }
    }

    private func archive() {
        editing?.isArchived = true
        dismiss()
    }
}
