import SwiftUI

enum SidebarDestination: Hashable {
    case dashboard
    case reports
    case goals
    case transactions
    case bills
    case recurringExpenses
    case categories
    case accounts
    case intelligence

    var title: String {
        switch self {
        case .dashboard: return "Visão geral"
        case .reports: return "Relatórios"
        case .goals: return "Metas"
        case .transactions: return "Lançamentos"
        case .bills: return "Contas a pagar"
        case .recurringExpenses: return "Despesas fixas"
        case .categories: return "Categorias"
        case .accounts: return "Contas"
        case .intelligence: return "Inteligência"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .reports: return "chart.bar.xaxis"
        case .goals: return "flag.fill"
        case .transactions: return "list.bullet.rectangle.fill"
        case .bills: return "calendar.badge.clock"
        case .recurringExpenses: return "repeat.circle.fill"
        case .categories: return "tag.fill"
        case .accounts: return "wallet.pass.fill"
        case .intelligence: return "sparkles"
        }
    }
}

struct SidebarDetailView: View {
    let destination: SidebarDestination?

    var body: some View {
        switch destination {
        case .dashboard:
            MonthDashboardView()
        case .reports:
            ReportsView()
        case .goals:
            GoalListView()
        case .transactions:
            TransactionListView()
        case .bills:
            BillListView()
        case .recurringExpenses:
            RecurringExpenseListView()
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

struct AIChatToolbarButton: View {
    @EnvironmentObject private var chatPanelState: AIChatPanelState

    var body: some View {
        Button {
            chatPanelState.toggle()
        } label: {
            Label("Saúde financeira", systemImage: "sparkles")
        }
        .help("Abrir chat de saúde financeira")
    }
}

struct AIChatPresentationModifier: ViewModifier {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.cfLayoutMode) private var layoutMode

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    AIChatToolbarButton()
                }
            }
            .overlay(alignment: .trailing) {
                if chatPanelState.isOpen && layoutMode != .compact {
                    AIChatSidePanel(aiService: aiService, presentation: .sidebarOverlay)
                        .transition(.move(edge: .trailing))
                        .shadow(color: .black.opacity(0.2), radius: 16, x: -4, y: 0)
                }
            }
            .animation(CFMotion.snappy, value: chatPanelState.isOpen)
            .sheet(isPresented: compactChatBinding) {
                AIChatSidePanel(aiService: aiService, presentation: .sheet)
                    .environmentObject(chatPanelState)
                    .environmentObject(aiService)
            }
    }

    private var compactChatBinding: Binding<Bool> {
        if layoutMode == .compact {
            Binding(
                get: { chatPanelState.isOpen },
                set: { chatPanelState.isOpen = $0 }
            )
        } else {
            .constant(false)
        }
    }
}

extension View {
    func aiChatPresentation() -> some View {
        modifier(AIChatPresentationModifier())
    }
}
