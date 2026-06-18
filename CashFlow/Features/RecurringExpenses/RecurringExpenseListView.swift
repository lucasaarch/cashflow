import SwiftUI
import SwiftData

struct RecurringExpenseListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var privacy: PrivacyMode

    @Query(sort: [SortDescriptor(\RecurringExpense.createdAt)])
    private var rules: [RecurringExpense]

    @State private var showingAdd = false
    @State private var editingRule: RecurringExpense?

    private var activeRules: [RecurringExpense] {
        rules.filter { !$0.isPaused }
    }

    private var pausedRules: [RecurringExpense] {
        rules.filter { $0.isPaused }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Nova despesa fixa", systemImage: "plus")
                }
                .help("Cadastrar despesa fixa")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddRecurringExpenseSheet()
        }
        .sheet(item: $editingRule) { rule in
            AddRecurringExpenseSheet(editing: rule)
        }
        .cfPageBackground()
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
        CFScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !activeRules.isEmpty {
                    section(title: "Ativas", rules: activeRules)
                }
                if !pausedRules.isEmpty {
                    section(title: "Pausadas", rules: pausedRules)
                }
            }
            .padding(20)
        }
    }

    private func section(title: String, rules: [RecurringExpense]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(rules) { rule in
                CFHoverRow {
                    rowContent(rule)
                }
                .contentShape(Rectangle())
                .onTapGesture { editingRule = rule }
                .contextMenu {
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
            }
        }
    }

    private func rowContent(_ rule: RecurringExpense) -> some View {
        HStack(spacing: 12) {
            CFIconBadge(
                symbolName: rule.category?.symbolName ?? "repeat",
                tint: rule.isPaused ? CFTheme.textSecondary : CFTheme.expense,
                size: 30
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(rule.name)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(subtitle(for: rule))
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(rule.amount.brl(masked: privacy.valuesHidden))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(CFTheme.textPrimary)
                Text(rule.account?.name ?? "Sem conta")
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textTertiary)
        }
        .opacity(rule.isPaused ? 0.65 : 1)
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
        // First delete future occurrences, keep past ones (they'll lose link via nullify).
        RecurringExpenseMaterializer.deleteUnrealizedOccurrences(rule: rule, context: modelContext)
        modelContext.delete(rule)
    }
}
