import SwiftUI

enum SidebarDestination: Hashable {
    case dashboard
    case goals
    case wishlist
    case investments
    case transactions
    case bills
    case receivables
    case recurringExpenses
    case recurringIncomes
    case categories
    case accounts
    case intelligence

    var title: String {
        switch self {
        case .dashboard: return "Visão geral"
        case .goals: return "Metas"
        case .wishlist: return "Lista de desejos"
        case .investments: return "Investimentos"
        case .transactions: return "Lançamentos"
        case .bills: return "Contas a pagar"
        case .receivables: return "Contas a receber"
        case .recurringExpenses: return "Despesas fixas"
        case .recurringIncomes: return "Rendas fixas"
        case .categories: return "Categorias"
        case .accounts: return "Contas"
        case .intelligence: return "Inteligência"
        }
    }

    var symbolName: String {
        switch self {
        case .dashboard: return "chart.pie.fill"
        case .goals: return "flag.fill"
        case .wishlist: return "cart.fill"
        case .investments: return "chart.line.uptrend.xyaxis"
        case .transactions: return "list.bullet.rectangle.fill"
        case .bills: return "calendar.badge.clock"
        case .receivables: return "tray.and.arrow.down.fill"
        case .recurringExpenses: return "repeat.circle.fill"
        case .recurringIncomes: return "arrow.down.circle.fill"
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
        case .goals:
            GoalListView()
        case .wishlist:
            WishlistListView()
        case .investments:
            InvestmentsView()
        case .transactions:
            TransactionListView()
        case .bills:
            BillListView()
        case .receivables:
            ReceivableListView()
        case .recurringExpenses:
            RecurringExpenseListView()
        case .recurringIncomes:
            RecurringIncomeListView()
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
            Label(AIAssistantIdentity.name, systemImage: "sparkles")
        }
        .help("Conversar com \(AIAssistantIdentity.name)")
    }
}

struct AIChatPresentationModifier: ViewModifier {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.cfLayoutMode) private var layoutMode

    func body(content: Content) -> some View {
        Group {
            if layoutMode == .compact {
                content
                    .toolbar { chatToolbarItems }
                    .sheet(isPresented: chatOpenBinding) {
                        AIChatSidePanel(aiService: aiService, presentation: .sheet)
                            .environmentObject(chatPanelState)
                            .environmentObject(aiService)
                    }
            } else {
                HStack(spacing: 0) {
                    content
                        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                        .toolbar { chatToolbarItems }

                    if chatPanelState.isOpen {
                        AIChatResizablePanel(aiService: aiService)
                    }
                }
                .animation(chatPanelState.isResizing ? nil : CFMotion.snappy, value: chatPanelState.isOpen)
            }
        }
    }

    @ToolbarContentBuilder
    private var chatToolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            PrivacyToggleToolbarButton()
            AIChatToolbarButton()
        }
    }

    private var chatOpenBinding: Binding<Bool> {
        Binding(
            get: { chatPanelState.isOpen },
            set: { newValue in
                if newValue {
                    chatPanelState.openFresh()
                } else {
                    chatPanelState.close()
                }
            }
        )
    }
}

private struct AIChatResizablePanel: View {
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    let aiService: AIService

    @State private var liveWidth: CGFloat?

    private var displayWidth: CGFloat {
        liveWidth ?? chatPanelState.panelWidth
    }

    var body: some View {
        AIChatSidePanel(aiService: aiService, presentation: .inlineColumn)
            .frame(width: displayWidth)
            .frame(minWidth: 0, maxHeight: .infinity)
            .clipped()
            .overlay(alignment: .leading) {
                CFTrailingPanelResizeHandle(
                    width: Binding(
                        get: { displayWidth },
                        set: { liveWidth = $0 }
                    ),
                    range: AIChatPanelState.minPanelWidth...AIChatPanelState.maxPanelWidth,
                    onDraggingChanged: { chatPanelState.isResizing = $0 },
                    onDragEnded: { finalWidth in
                        chatPanelState.setPanelWidth(finalWidth)
                        liveWidth = nil
                    }
                )
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
    }
}

extension View {
    func aiChatPresentation() -> some View {
        modifier(AIChatPresentationModifier())
    }
}
