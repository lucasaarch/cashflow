import SwiftUI
import SwiftData

struct WishlistListView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif

    @Query private var items: [WishlistItem]

    @State private var showingAdd = false
    @State private var editingItem: WishlistItem?
    @State private var purchasingItem: WishlistItem?
    #if os(macOS)
    @State private var highlightedItemID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif

    private var sortedItems: [WishlistItem] {
        WishlistSortOrder.sorted(items)
    }

    private var totalEstimated: Decimal {
        items.reduce(0) { $0 + $1.estimatedAmount }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Lista de desejos")
        .detailToolbarAdd(help: "Cadastrar item na lista de desejos") {
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            AddWishlistItemSheet()
        }
        .sheet(item: $editingItem) { item in
            AddWishlistItemSheet(editing: item)
        }
        .sheet(item: $purchasingItem) { item in
            PurchaseWishlistItemSheet(item: item)
        }
        .cfGlassDetailChrome()
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "cart",
            title: "Nenhum desejo cadastrado",
            message: "Cadastre compras que você quer fazer eventualmente — a \(AIAssistantIdentity.name) ajuda a escolher o melhor momento.",
            actionTitle: "Adicionar desejo"
        ) {
            showingAdd = true
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            CFGlassPage {
                CFGlassPageStack {
                    CFGlassSummaryPanel(title: "Total estimado", staggerIndex: 0) {
                        WishlistSummaryHeader(totalEstimated: totalEstimated, items: items)
                    }

                    CFGlassSection(
                        title: "Itens",
                        count: sortedItems.count,
                        countTint: CFTheme.accent,
                        staggerIndex: 1
                    ) {
                        CFGlassEnumeratedPanel(items: sortedItems) { item, _ in
                            CFGlassRowButton {
                                editingItem = item
                            } label: {
                                WishlistItemRow(item: item)
                            }
                            .id(item.id)
                            #if os(macOS)
                            .spotlightFocused(highlightedItemID == item.id)
                            #endif
                            .contextMenu {
                                Button {
                                    purchasingItem = item
                                } label: {
                                    Label("Comprei", systemImage: "checkmark.circle")
                                }
                                Button {
                                    editingItem = item
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    modelContext.delete(item)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            #if os(macOS)
            .spotlightScrollTarget(
                navigation: spotlightNavigation,
                kind: .wishlistItem,
                highlightedID: $highlightedItemID,
                focusTask: $spotlightFocusTask,
                proxy: proxy,
                onReveal: { id in
                    if let item = items.first(where: { $0.id == id }) {
                        editingItem = item
                    }
                }
            )
            #endif
        }
    }
}
