import SwiftUI
import SwiftData

struct RecurringExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif

    @Query(sort: [SortDescriptor(\RecurringExpense.createdAt)])
    private var rules: [RecurringExpense]

    @State private var showingAdd = false
    @State private var editingRule: RecurringExpense?
    #if os(macOS)
    @State private var highlightedRuleID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif

    private var activeRules: [RecurringExpense] { rules.filter { !$0.isPaused } }
    private var pausedRules: [RecurringExpense] { rules.filter { $0.isPaused } }

    private var ruleSections: [(title: String, tint: Color, rules: [RecurringExpense])] {
        var sections: [(String, Color, [RecurringExpense])] = []
        if !activeRules.isEmpty { sections.append(("Ativas", CFTheme.expense, activeRules)) }
        if !pausedRules.isEmpty { sections.append(("Pausadas", CFTheme.textSecondary, pausedRules)) }
        return sections
    }

    var body: some View {
        Group {
            if rules.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Despesas fixas")
        .detailToolbarAdd(help: "Cadastrar despesa fixa") {
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            AddRecurringExpenseSheet()
        }
        .sheet(item: $editingRule) { rule in
            AddRecurringExpenseSheet(editing: rule)
        }
        .cfGlassDetailChrome()
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "repeat.circle",
            title: "Sem despesas fixas",
            message: "Cadastre o que se repete todo mês — assinaturas, aluguel, plano de saúde. Eles entram automaticamente em \"Previsto\" do mês.",
            actionTitle: "Cadastrar primeira"
        ) {
            showingAdd = true
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            CFGlassPage {
                CFGlassPageStack {
                    ForEach(Array(ruleSections.enumerated()), id: \.offset) { index, section in
                        ruleSection(
                            title: section.title,
                            tint: section.tint,
                            rules: section.rules,
                            staggerIndex: index
                        )
                    }
                }
            }
            #if os(macOS)
            .spotlightScrollTarget(
                navigation: spotlightNavigation,
                kind: .recurringExpense,
                highlightedID: $highlightedRuleID,
                focusTask: $spotlightFocusTask,
                proxy: proxy,
                onReveal: { id in
                    if let rule = rules.first(where: { $0.id == id }) {
                        editingRule = rule
                    }
                }
            )
            #endif
        }
    }

    private func ruleSection(
        title: String,
        tint: Color,
        rules: [RecurringExpense],
        staggerIndex: Int
    ) -> some View {
        CFGlassSection(
            title: title,
            count: rules.count,
            countTint: tint,
            staggerIndex: staggerIndex
        ) {
            CFGlassEnumeratedPanel(items: rules) { rule, _ in
                CFGlassRowButton {
                    editingRule = rule
                } label: {
                    rowContent(rule)
                }
                .id(rule.id)
                #if os(macOS)
                .spotlightFocused(highlightedRuleID == rule.id)
                #endif
                .contextMenu {
                    ruleContextMenu(rule)
                }
            }
        }
    }

    @ViewBuilder
    private func ruleContextMenu(_ rule: RecurringExpense) -> some View {
        Button {
            editingRule = rule
        } label: {
            Label("Editar", systemImage: "pencil")
        }
        Button {
            togglePause(rule)
        } label: {
            Label(rule.isPaused ? "Retomar" : "Pausar", systemImage: rule.isPaused ? "play.fill" : "pause.fill")
        }
        Divider()
        Button(role: .destructive) {
            deleteAll(rule)
        } label: {
            Label("Excluir tudo (regra + ocorrências)", systemImage: "trash")
        }
        Button(role: .destructive) {
            deleteRuleOnly(rule)
        } label: {
            Label("Manter histórico, remover regra", systemImage: "xmark.bin")
        }
    }

    private func rowContent(_ rule: RecurringExpense) -> some View {
        CFGlassAmountRow(
            systemName: rule.category?.symbolName ?? "repeat",
            tint: rule.isPaused ? CFTheme.textSecondary : CFTheme.expense,
            title: rule.name,
            subtitle: subtitle(for: rule),
            amount: rule.amount.brl,
            trailingCaption: rule.account?.name ?? "Sem conta",
            showsChevron: true,
            dimmed: rule.isPaused
        )
    }

    private func subtitle(for rule: RecurringExpense) -> String {
        let dayText = "Todo dia \(rule.dayOfMonth)"
        if let end = rule.endDate {
            let formatter = Date.FormatStyle.dateTime.month(.abbreviated).year().locale(Money.locale)
            return "\(dayText) · até \(end.formatted(formatter))"
        }
        return "\(dayText) · sem prazo"
    }

    private func togglePause(_ rule: RecurringExpense) {
        rule.isPaused.toggle()
        if rule.isPaused {
            RecurringExpenseMaterializer.deleteUnrealizedOccurrences(rule: rule, context: modelContext)
        } else {
            RecurringExpenseMaterializer.materialize(
                rule: rule,
                horizon: Date.now.addingTimeInterval(RecurringExpenseMaterializer.defaultHorizon),
                context: modelContext
            )
        }
    }

    private func deleteAll(_ rule: RecurringExpense) {
        for txn in rule.transactions {
            modelContext.delete(txn)
        }
        modelContext.delete(rule)
    }

    private func deleteRuleOnly(_ rule: RecurringExpense) {
        RecurringExpenseMaterializer.deleteUnrealizedOccurrences(rule: rule, context: modelContext)
        modelContext.delete(rule)
    }
}
