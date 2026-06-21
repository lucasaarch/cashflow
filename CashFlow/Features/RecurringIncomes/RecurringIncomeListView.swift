import SwiftUI
import SwiftData

struct RecurringIncomeListView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif

    @Query(sort: [SortDescriptor(\RecurringIncome.createdAt)])
    private var rules: [RecurringIncome]

    @State private var showingAdd = false
    @State private var editingRule: RecurringIncome?
    #if os(macOS)
    @State private var highlightedRuleID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif

    private var activeRules: [RecurringIncome] { rules.filter { !$0.isPaused } }
    private var pausedRules: [RecurringIncome] { rules.filter { $0.isPaused } }

    private var ruleSections: [(title: String, tint: Color, rules: [RecurringIncome])] {
        var sections: [(String, Color, [RecurringIncome])] = []
        if !activeRules.isEmpty { sections.append(("Ativas", CFTheme.income, activeRules)) }
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
        .navigationTitle("Rendas fixas")
        .detailToolbarAdd(help: "Cadastrar renda fixa") {
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            AddRecurringIncomeSheet()
        }
        .sheet(item: $editingRule) { rule in
            AddRecurringIncomeSheet(editing: rule)
        }
        .cfGlassDetailChrome()
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "arrow.down.circle",
            title: "Sem rendas fixas",
            message: "Cadastre o que entra todo mês — salário, bolsa, aluguel recebido. O app calcula sua renda esperada automaticamente a partir daqui.",
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
                kind: .recurringIncome,
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
        rules: [RecurringIncome],
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
    private func ruleContextMenu(_ rule: RecurringIncome) -> some View {
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

    private func rowContent(_ rule: RecurringIncome) -> some View {
        CFGlassAmountRow(
            systemName: rule.category?.symbolName ?? "arrow.down.circle",
            tint: rule.isPaused ? CFTheme.textSecondary : CFTheme.income,
            title: rule.name,
            subtitle: subtitle(for: rule),
            amount: rule.amount.brl,
            amountColor: CFTheme.income,
            trailingCaption: rule.account?.name ?? "Sem conta",
            showsChevron: true,
            dimmed: rule.isPaused
        )
    }

    private func subtitle(for rule: RecurringIncome) -> String {
        let dayText = "Todo dia \(rule.dayOfMonth)"
        let mode = rule.requiresConfirmation ? "confirmação manual" : "lançamento automático"
        if let end = rule.endDate {
            let formatter = Date.FormatStyle.dateTime.month(.abbreviated).year().locale(Money.locale)
            return "\(dayText) · \(mode) · até \(end.formatted(formatter))"
        }
        return "\(dayText) · \(mode)"
    }

    private func togglePause(_ rule: RecurringIncome) {
        rule.isPaused.toggle()
        if rule.isPaused {
            RecurringIncomeMaterializer.deleteUnrealizedOccurrences(rule: rule, context: modelContext)
        } else {
            RecurringIncomeMaterializer.materialize(
                rule: rule,
                horizon: Date.now.addingTimeInterval(RecurringIncomeMaterializer.defaultHorizon),
                context: modelContext
            )
        }
    }

    private func deleteAll(_ rule: RecurringIncome) {
        for txn in rule.transactions {
            modelContext.delete(txn)
        }
        for receivable in rule.receivables {
            ReceivableNotifications.cancel(for: receivable)
            modelContext.delete(receivable)
        }
        modelContext.delete(rule)
    }

    private func deleteRuleOnly(_ rule: RecurringIncome) {
        RecurringIncomeMaterializer.deleteUnrealizedOccurrences(rule: rule, context: modelContext)
        modelContext.delete(rule)
    }
}
