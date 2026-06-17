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
        ContentUnavailableView {
            Label("Nenhuma categoria", systemImage: "tag")
        } description: {
            Text("Crie categorias para classificar seus gastos e receitas (ex: Mercado, Delivery, Salário).")
        } actions: {
            Button {
                showingAdd = true
            } label: {
                Label("Criar primeira categoria", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var categoryList: some View {
        List {
            if !expenseCategories.isEmpty {
                Section("Despesas") {
                    ForEach(expenseCategories) { category in
                        categoryRow(category, tint: .red)
                    }
                }
            }

            if !incomeCategories.isEmpty {
                Section("Receitas") {
                    ForEach(incomeCategories) { category in
                        categoryRow(category, tint: .green)
                    }
                }
            }

            if !archivedCategories.isEmpty {
                Section("Arquivadas") {
                    ForEach(archivedCategories) { category in
                        HStack(spacing: 12) {
                            categoryIcon(category, tint: .secondary)
                            Text(category.name)
                                .foregroundStyle(.secondary)
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
        .listStyle(.inset)
    }

    @ViewBuilder
    private func categoryRow(_ category: Category, tint: Color) -> some View {
        HStack(spacing: 12) {
            categoryIcon(category, tint: tint)
            Text(category.name)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                category.isArchived = true
            } label: {
                Label("Arquivar", systemImage: "archivebox")
            }
        }
    }

    private func categoryIcon(_ category: Category, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 28, height: 28)
            Image(systemName: category.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
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

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Nome") {
                        TextField("Mercado, Delivery…", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                    }
                    LabeledContent("Tipo") {
                        Picker("", selection: $kind) {
                            Text("Despesa").tag(CategoryKind.expense)
                            Text("Receita").tag(CategoryKind.income)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 200)
                        .disabled(hasUsage)
                    }
                    if hasUsage {
                        Text("Tipo não pode ser trocado porque há lançamentos usando essa categoria. Arquive e crie uma nova se precisar mudar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Ícone") {
                    LabeledContent("Ícone") {
                        IconPickerField(symbolName: $symbolName,
                                        tint: kind == .expense ? .red : .green)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if isEditing {
                    Button(role: .destructive) {
                        archive()
                    } label: {
                        Label("Arquivar", systemImage: "archivebox")
                    }
                }
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 460, height: 360)
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
