import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var privacy: PrivacyMode
    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse),
                  SortDescriptor(\Transaction.createdAt, order: .reverse)])
    private var transactions: [Transaction]

    @Query(filter: #Predicate<Account> { !$0.isArchived })
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived })
    private var categories: [Category]

    @State private var showingAdd = false
    @State private var editingTransaction: Transaction?

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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Novo lançamento", systemImage: "plus")
                }
                .disabled(!canAddTransaction)
                .help(canAddTransaction ? "Novo lançamento" : "Cadastre conta e categoria primeiro")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddTransactionSheet()
        }
        .sheet(item: $editingTransaction) { transaction in
            AddTransactionSheet(editing: transaction)
        }
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
        CFScrollView {
            LazyVStack(spacing: 4, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedByDay, id: \.0) { day, items in
                    Section {
                        ForEach(items) { transaction in
                            CFHoverRow {
                                TransactionRow(transaction: transaction)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTransaction = transaction
                            }
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
                            .padding(.bottom, 2)
                        }
                    } header: {
                        dayHeaderView(for: day, total: dayTotal(items))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .cfPageBackground()
    }

    private func dayHeaderView(for day: Date, total: Decimal) -> some View {
        HStack {
            Text(dayHeader(day))
                .font(CFTheme.headline())
                .foregroundStyle(CFTheme.textPrimary)
            Spacer()
            Text(total.brl(masked: privacy.valuesHidden))
                .font(CFTheme.kpiValue())
                .foregroundStyle(signedAmountColor(total))
                .frame(minWidth: TransactionListMetrics.amountColumnMinWidth, alignment: .trailing)
        }
        .padding(.horizontal, TransactionListMetrics.rowContentInset)
        .padding(.vertical, 8)
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
