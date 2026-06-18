import SwiftUI
import SwiftData

struct WishlistListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var privacy: PrivacyMode

    @Query private var items: [WishlistItem]

    @State private var showingAdd = false
    @State private var editingItem: WishlistItem?
    @State private var purchasingItem: WishlistItem?
    @State private var searchText = ""

    private var sortedItems: [WishlistItem] {
        WishlistSortOrder.sorted(items)
    }

    private var filteredItems: [WishlistItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return sortedItems }
        return sortedItems.filter { $0.name.lowercased().contains(query) }
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
        .searchable(text: $searchText, placement: .toolbar, prompt: "Buscar por nome")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Novo desejo", systemImage: "plus")
                }
                .help("Cadastrar item na lista de desejos")
            }
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
        .cfPageBackground()
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
        CFScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                WishlistSummaryHeader(totalEstimated: totalEstimated, items: items)

                itemsSection
            }
            .padding(20)
        }
    }

    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Itens")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(filteredItems) { item in
                CFHoverRow {
                    WishlistItemRow(item: item)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingItem = item
                }
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
