import SwiftUI
import SwiftData

struct RootSidebarView: View {
    @Query private var allBills: [Bill]
    @Query private var allReceivables: [Receivable]

    var pinSidebar: Bool

    @State private var selection: SidebarDestination? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(pinSidebar: Bool = true) {
        self.pinSidebar = pinSidebar
    }

    private var pendingBills: [Bill] {
        allBills.filter { $0.isPending }
    }

    private var overdueCount: Int {
        let now = Date.now
        return pendingBills.filter { $0.dueDate < now }.count
    }

    private var pendingBillsCount: Int? {
        guard !pendingBills.isEmpty else { return nil }
        return pendingBills.count
    }

    private var pendingReceivables: [Receivable] {
        allReceivables.filter { $0.isPending }
    }

    private var lateReceivablesCount: Int {
        let now = Date.now
        return pendingReceivables.filter { $0.expectedDate < now }.count
    }

    private var pendingReceivablesCount: Int? {
        guard !pendingReceivables.isEmpty else { return nil }
        return pendingReceivables.count
    }

    private var billsSidebarRow: some View {
        HStack {
            Label("Contas a pagar", systemImage: "calendar.badge.clock")
            Spacer(minLength: 0)
            if overdueCount > 0 {
                Text("\(overdueCount)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(CFTheme.danger))
            } else if let pendingBillsCount {
                Text("\(pendingBillsCount)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CFTheme.textSecondary)
            }
        }
        .tag(SidebarDestination.bills)
    }

    private var receivablesSidebarRow: some View {
        HStack {
            Label("Contas a receber", systemImage: "tray.and.arrow.down.fill")
            Spacer(minLength: 0)
            if lateReceivablesCount > 0 {
                Text("\(lateReceivablesCount)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(CFTheme.warning))
            } else if let pendingReceivablesCount {
                Text("\(pendingReceivablesCount)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CFTheme.textSecondary)
            }
        }
        .tag(SidebarDestination.receivables)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                Section("Visão") {
                    Label("Visão geral", systemImage: "chart.pie.fill")
                        .tag(SidebarDestination.dashboard)
                    Label("Metas", systemImage: "flag.fill")
                        .tag(SidebarDestination.goals)
                    Label("Lista de desejos", systemImage: "cart.fill")
                        .tag(SidebarDestination.wishlist)
                    Label("Investimentos", systemImage: "chart.line.uptrend.xyaxis")
                        .tag(SidebarDestination.investments)
                }

                Section("Movimentações") {
                    Label("Lançamentos", systemImage: "list.bullet.rectangle.fill")
                        .tag(SidebarDestination.transactions)
                    billsSidebarRow
                    receivablesSidebarRow
                    Label("Despesas fixas", systemImage: "repeat.circle.fill")
                        .tag(SidebarDestination.recurringExpenses)
                    Label("Rendas fixas", systemImage: "arrow.down.circle.fill")
                        .tag(SidebarDestination.recurringIncomes)
                }

                Section("Cadastros") {
                    Label("Categorias", systemImage: "tag.fill")
                        .tag(SidebarDestination.categories)
                    Label("Contas", systemImage: "wallet.pass.fill")
                        .tag(SidebarDestination.accounts)
                }

                Section("Inteligência") {
                    Label("Inteligência", systemImage: "sparkles")
                        .tag(SidebarDestination.intelligence)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("CashFlow")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            SidebarDetailView(destination: selection)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .aiChatPresentation()
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: columnVisibility) { _, newValue in
            if pinSidebar, newValue != .all {
                columnVisibility = .all
            }
        }
#if os(macOS)
        .removeSidebarToggleButton()
#endif
    }
}
