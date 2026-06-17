import SwiftUI

enum SidebarDestination: Hashable {
    case dashboard
    case transactions
    case categories
    case accounts
    case intelligence
}

struct RootSidebarView: View {
    @State private var selection: SidebarDestination? = .dashboard
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(selection: $selection) {
                Section("Visão") {
                    Label("Visão geral", systemImage: "chart.pie.fill")
                        .tag(SidebarDestination.dashboard)
                }

                Section("Movimentações") {
                    Label("Lançamentos", systemImage: "list.bullet.rectangle.fill")
                        .tag(SidebarDestination.transactions)
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
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: columnVisibility) { _, newValue in
            if newValue != .all {
                columnVisibility = .all
            }
        }
        .background(CFTheme.surfacePrimary)
#if os(macOS)
        .removeSidebarToggleButton()
#endif
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .dashboard:
            MonthDashboardView()
        case .transactions:
            TransactionListView()
        case .categories:
            CategoriesView()
        case .accounts:
            AccountsView()
        case .intelligence:
            AISettingsView()
        case .none:
            ContentUnavailableView(
                "Selecione uma seção",
                systemImage: "sidebar.left",
                description: Text("Escolha um item na barra lateral.")
            )
        }
    }
}
