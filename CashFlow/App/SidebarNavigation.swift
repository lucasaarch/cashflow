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
        case .intelligence: return AIAssistantIdentity.settingsSymbolName
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
            Image(systemName: AIAssistantIdentity.toolbarSymbolName)
        }
        .cfGlassToolbarIconButton()
        .help("Conversar com \(AIAssistantIdentity.name) (⌘⇧G)")
    }
}

struct SpotlightToolbarButton: View {
    @EnvironmentObject private var spotlightState: SpotlightPresentationState

    var body: some View {
        Button {
            spotlightState.toggle()
        } label: {
            Image(systemName: "magnifyingglass")
                .symbolVariant(spotlightState.isPresented ? .fill : .none)
        }
        .cfGlassToolbarIconButton()
        .help("Buscar em tudo (⌘K)")
    }
}

struct AIChatPresentationModifier: ViewModifier {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Environment(\.cfLayoutMode) private var layoutMode
    @State private var detailToolbarAdd: DetailToolbarAddAction?
    @State private var liveResizeWidth: CGFloat?

    private var usesInlineChatInspector: Bool {
        layoutMode == .regular
    }

    private var displayedPanelWidth: CGFloat {
        guard chatPanelState.isOpen else { return 0 }
        return liveResizeWidth ?? chatPanelState.panelWidth
    }

    func body(content: Content) -> some View {
        Group {
            if usesInlineChatInspector {
                if chatPanelState.isOpen {
                    HStack(spacing: 0) {
                        content
                            .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                            .toolbar { chatToolbarItems }

                        Color.clear
                            .frame(width: displayedPanelWidth)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .trailing) {
                        AIChatInspectorColumn(
                            liveWidth: $liveResizeWidth,
                            aiService: aiService
                        )
                        .frame(width: displayedPanelWidth)
                        .frame(maxHeight: .infinity)
                        .ignoresSafeArea()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    .animation(chatPanelState.isResizing ? nil : CFMotion.snappy, value: chatPanelState.isOpen)
                } else {
                    content
                        .toolbar { chatToolbarItems }
                }
            } else {
                content
                    .toolbar { chatToolbarItems }
                    .sheet(isPresented: chatOpenBinding) {
                        AIChatSidePanel(aiService: aiService, presentation: .sheet)
                            .environmentObject(chatPanelState)
                            .environmentObject(aiService)
                    }
            }
        }
        .onPreferenceChange(DetailToolbarAddPreferenceKey.self) { detailToolbarAdd = $0 }
    }

    @ToolbarContentBuilder
    private var chatToolbarItems: some ToolbarContent {
        DetailToolbarItems(addAction: detailToolbarAdd)
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

private struct AIChatInspectorColumn: View {
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @Binding var liveWidth: CGFloat?
    let aiService: AIService

    private var displayWidth: CGFloat {
        liveWidth ?? chatPanelState.panelWidth
    }

    var body: some View {
        ZStack(alignment: .top) {
            CFGlassChatPanelBackground()
                .ignoresSafeArea()

            AIChatSidePanel(
                aiService: aiService,
                presentation: .inlineColumn
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .overlay(alignment: .leading) {
            CFTrailingPanelResizeHandle(
                width: Binding(
                    get: { displayWidth },
                    set: { liveWidth = $0 }
                ),
                range: AIChatPanelState.minPanelWidth...AIChatPanelState.maxPanelWidth,
                onDraggingChanged: { isDragging in
                    chatPanelState.isResizing = isDragging
                },
                onDragEnded: { finalWidth in
                    chatPanelState.setPanelWidth(finalWidth)
                    liveWidth = nil
                }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func aiChatPresentation() -> some View {
        modifier(AIChatPresentationModifier())
    }
}
