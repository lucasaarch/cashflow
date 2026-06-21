import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse),
                  SortDescriptor(\Transaction.createdAt, order: .reverse)])
    private var transactions: [Transaction]

    @Query(filter: #Predicate<Account> { !$0.isArchived })
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived })
    private var categories: [Category]

    @State private var showingAdd = false
    @State private var editingTransaction: Transaction?
    #if os(macOS)
    @State private var highlightedTransactionID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif

    private var canAddTransaction: Bool {
        !accounts.isEmpty && !categories.isEmpty
    }

    var body: some View {
        Group {
            if transactions.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Lançamentos")
        .detailToolbarAdd(
            help: canAddTransaction ? "Novo lançamento" : "Cadastre conta e categoria primeiro",
            disabled: !canAddTransaction
        ) {
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            AddTransactionSheet()
        }
        .sheet(item: $editingTransaction) { transaction in
            AddTransactionSheet(editing: transaction)
        }
        .cfGlassDetailChrome()
    }

    @ViewBuilder
    private var emptyState: some View {
        if accounts.isEmpty {
            CFEmptyState(
                symbol: "wallet.pass",
                title: "Cadastre uma conta primeiro",
                message: "Você precisa de pelo menos uma conta com saldo de partida antes de registrar movimentações."
            )
        } else if categories.isEmpty {
            CFEmptyState(
                symbol: "tag",
                title: "Crie ao menos uma categoria",
                message: "Cadastre categorias para classificar seus gastos e receitas."
            )
        } else {
            CFEmptyState(
                symbol: "list.bullet.rectangle",
                title: "Nenhum lançamento",
                message: "Comece registrando seu primeiro gasto ou receita.",
                actionTitle: "Novo lançamento"
            ) {
                showingAdd = true
            }
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            CFGlassPage(maxWidth: CFGlassMetrics.wideContentMaxWidth) {
                CFGlassPageStack {
                    ForEach(Array(groupedByDay.enumerated()), id: \.element.0) { index, group in
                        let (day, items) = group
                        VStack(alignment: .leading, spacing: 10) {
                            CFGlassDayHeader(
                                title: dayHeader(day),
                                amount: dayTotal(items),
                                amountColor: signedAmountColor(dayTotal(items))
                            )
                            .padding(.horizontal, 4)

                            CFGlassEnumeratedPanel(items: items, dividerStyle: .fullWidth) { transaction, _ in
                                CFGlassRowButton {
                                    editingTransaction = transaction
                                } label: {
                                    TransactionRow(transaction: transaction)
                                }
                                .id(transaction.id)
                                #if os(macOS)
                                .spotlightFocused(highlightedTransactionID == transaction.id)
                                #endif
                                .contextMenu {
                                    Button {
                                        editingTransaction = transaction
                                    } label: {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(transaction)
                                    } label: {
                                        Label("Excluir", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .cfStaggerAppear(index: index)
                    }
                }
            }
            #if os(macOS)
            .spotlightScrollTarget(
                navigation: spotlightNavigation,
                kind: .transaction,
                highlightedID: $highlightedTransactionID,
                focusTask: $spotlightFocusTask,
                proxy: proxy,
                onReveal: { id in
                    if let transaction = transactions.first(where: { $0.id == id }) {
                        editingTransaction = transaction
                    }
                }
            )
            #endif
        }
    }

    private func signedAmountColor(_ amount: Decimal) -> Color {
        if amount > 0 { return CFTheme.income }
        if amount < 0 { return CFTheme.warning }
        return CFTheme.textSecondary
    }

    private var groupedByDay: [(Date, [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { transaction in
            Calendar.current.startOfDay(for: transaction.occurredOn)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func dayTotal(_ items: [Transaction]) -> Decimal {
        items.reduce(Decimal(0)) { partial, transaction in
            partial + (transaction.kind == .expense ? -transaction.amount : transaction.amount)
        }
    }

    private func dayHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoje" }
        if calendar.isDateInYesterday(date) { return "Ontem" }
        if calendar.isDateInTomorrow(date) { return "Amanhã" }
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Money.locale))
            .capitalized
    }

}
