import SwiftUI
import SwiftData

struct TransactionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse),
                  SortDescriptor(\Transaction.createdAt, order: .reverse)])
    private var transactions: [Transaction]

    @Query(filter: #Predicate<Account> { !$0.isArchived })
    private var accounts: [Account]

    @Query(filter: #Predicate<Category> { !$0.isArchived })
    private var categories: [Category]

    @State private var showingAdd = false

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
    }

    @ViewBuilder
    private var emptyState: some View {
        if accounts.isEmpty {
            ContentUnavailableView {
                Label("Cadastre uma conta primeiro", systemImage: "wallet.pass")
            } description: {
                Text("Você precisa de pelo menos uma conta com saldo de partida antes de registrar movimentações.")
            }
        } else if categories.isEmpty {
            ContentUnavailableView {
                Label("Crie ao menos uma categoria", systemImage: "tag")
            } description: {
                Text("Cadastre categorias para classificar seus gastos e receitas.")
            }
        } else {
            ContentUnavailableView {
                Label("Nenhum lançamento", systemImage: "list.bullet.rectangle")
            } description: {
                Text("Comece registrando seu primeiro gasto ou receita.")
            } actions: {
                Button {
                    showingAdd = true
                } label: {
                    Label("Novo lançamento", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var list: some View {
        List {
            ForEach(groupedByDay, id: \.0) { day, items in
                Section {
                    ForEach(items) { transaction in
                        TransactionRow(transaction: transaction)
                            .listRowSeparatorTint(.secondary.opacity(0.15))
                    }
                    .onDelete { offsets in
                        delete(from: items, at: offsets)
                    }
                } header: {
                    sectionHeader(for: day, total: dayTotal(items))
                }
            }
        }
        .listStyle(.inset)
    }

    private func sectionHeader(for day: Date, total: Decimal) -> some View {
        HStack {
            Text(dayHeader(day))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text(total.brl)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .textCase(nil)
        .padding(.vertical, 2)
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
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Money.locale))
            .capitalized
    }

    private func delete(from items: [Transaction], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}
