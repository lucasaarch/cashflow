import SwiftUI
import SwiftData

struct RootSidebarView: View {
    @Query private var allBills: [Bill]

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

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                Section("Visão") {
                    Label("Visão geral", systemImage: "chart.pie.fill")
                        .tag(SidebarDestination.dashboard)
                    Label("Relatórios", systemImage: "chart.bar.xaxis")
                        .tag(SidebarDestination.reports)
                    Label("Metas", systemImage: "flag.fill")
                        .tag(SidebarDestination.goals)
                }

                Section("Movimentações") {
                    Label("Lançamentos", systemImage: "list.bullet.rectangle.fill")
                        .tag(SidebarDestination.transactions)
                    billsSidebarRow
                    Label("Despesas fixas", systemImage: "repeat.circle.fill")
                        .tag(SidebarDestination.recurringExpenses)
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
