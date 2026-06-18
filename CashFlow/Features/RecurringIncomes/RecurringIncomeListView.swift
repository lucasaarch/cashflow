import SwiftUI
import SwiftData

struct RecurringIncomeListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\RecurringIncome.createdAt)])
    private var rules: [RecurringIncome]

    @State private var showingAdd = false
    @State private var editingRule: RecurringIncome?

    private var activeRules: [RecurringIncome] {
        rules.filter { !$0.isPaused }
    }

    private var pausedRules: [RecurringIncome] {
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
        .navigationTitle("Rendas fixas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Nova renda fixa", systemImage: "plus")
                }
                .help("Cadastrar renda fixa")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddRecurringIncomeSheet()
        }
        .sheet(item: $editingRule) { rule in
            AddRecurringIncomeSheet(editing: rule)
        }
        .cfPageBackground()
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
        ScrollView {
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

    private func section(title: String, rules: [RecurringIncome]) -> some View {
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

    private func rowContent(_ rule: RecurringIncome) -> some View {
        HStack(spacing: 12) {
            CFIconBadge(
                symbolName: rule.category?.symbolName ?? "arrow.down.circle",
                tint: rule.isPaused ? CFTheme.textSecondary : CFTheme.income,
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
                Text(rule.amount.brl)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(CFTheme.income)
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
