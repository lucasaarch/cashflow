import SwiftUI

enum SidebarDestination: Hashable {
    case dashboard
    case transactions
    case categories
    case accounts
}

struct RootSidebarView: View {
    @State private var selection: SidebarDestination? = .dashboard

    var body: some View {
        NavigationSplitView {
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
            }
            .listStyle(.sidebar)
            .navigationTitle("CashFlow")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
        .tint(CFTheme.brandGreen)
        .background(CFTheme.surfacePrimary)
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
        case .none:
            ContentUnavailableView(
                "Selecione uma seção",
                systemImage: "sidebar.left",
                description: Text("Escolha um item na barra lateral.")
            )
        }
    }
}
