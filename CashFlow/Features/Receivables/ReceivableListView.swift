import SwiftUI
import SwiftData

struct ReceivableListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @EnvironmentObject private var aiService: AIService
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif

    @Query(sort: [SortDescriptor(\Receivable.expectedDate)])
    private var receivables: [Receivable]

    @State private var showingAdd = false
    @State private var editingReceivable: Receivable?
    @State private var confirmingReceivable: Receivable?
    @State private var reschedulingReceivable: Receivable?
    #if os(macOS)
    @State private var highlightedReceivableID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif

    private var visibleReceivables: [Receivable] {
        receivables.filter { $0.status != .cancelled }
    }

    private var late: [Receivable] {
        visibleReceivables.filter { $0.isLate() }
    }

    private var upcoming: [Receivable] {
        visibleReceivables.filter { $0.isPending && !$0.isLate() }
    }

    private var received: [Receivable] {
        visibleReceivables.filter { $0.isReceived }
            .sorted { ($0.receivedOn ?? .distantPast) > ($1.receivedOn ?? .distantPast) }
    }

    var body: some View {
        Group {
            if receivables.filter({ $0.status != .cancelled }).isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Contas a receber")
        .detailToolbarAdd(help: "Cadastrar conta a receber") {
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            AddReceivableSheet()
        }
        .sheet(item: $editingReceivable) { receivable in
            AddReceivableSheet(editing: receivable)
        }
        .sheet(item: $confirmingReceivable) { receivable in
            ConfirmReceivableSheet(receivable: receivable)
        }
        .sheet(item: $reschedulingReceivable) { receivable in
            RescheduleSheet(
                title: "Reagendar recebível",
                subtitle: receivable.name,
                initialDate: receivable.expectedDate
            ) { newDate in
                receivable.expectedDate = Calendar.current.startOfDay(for: newDate)
                ReceivableNotifications.schedule(for: receivable)
            }
        }
        .cfGlassDetailChrome()
    }

    private var receivableSections: [(title: String, tint: Color, items: [Receivable])] {
        var sections: [(String, Color, [Receivable])] = []
        if !late.isEmpty { sections.append(("Atrasadas", CFTheme.warning, late)) }
        if !upcoming.isEmpty { sections.append(("A receber", CFTheme.accent, upcoming)) }
        if !received.isEmpty { sections.append(("Recebidas", CFTheme.income, received)) }
        return sections
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "tray.and.arrow.down",
            title: "Sem recebíveis pendentes",
            message: "Cadastre dinheiro que você ainda vai receber — salário, freelas, reembolsos — e confirme manualmente quando entrar.",
            actionTitle: "Cadastrar recebível"
        ) {
            showingAdd = true
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            CFGlassPage {
                CFGlassPageStack {
                    ForEach(Array(receivableSections.enumerated()), id: \.offset) { index, section in
                        receivableSection(
                            title: section.title,
                            tint: section.tint,
                            items: section.items,
                            staggerIndex: index
                        )
                    }
                }
            }
            #if os(macOS)
            .spotlightScrollTarget(
                navigation: spotlightNavigation,
                kind: .receivable,
                highlightedID: $highlightedReceivableID,
                focusTask: $spotlightFocusTask,
                proxy: proxy,
                onReveal: { id in
                    if let receivable = receivables.first(where: { $0.id == id }) {
                        openReceivable(receivable)
                    }
                }
            )
            #endif
        }
    }

    private func receivableSection(
        title: String,
        tint: Color,
        items: [Receivable],
        staggerIndex: Int
    ) -> some View {
        CFGlassSection(
            title: title,
            count: items.count,
            countTint: tint,
            staggerIndex: staggerIndex
        ) {
            CFGlassEnumeratedPanel(items: items) { receivable, _ in
                CFGlassRowButton {
                    openReceivable(receivable)
                } label: {
                    rowContent(receivable)
                }
                .id(receivable.id)
                #if os(macOS)
                .spotlightFocused(highlightedReceivableID == receivable.id)
                #endif
                .contextMenu {
                    receivableContextMenu(receivable)
                }
            }
        }
    }

    @ViewBuilder
    private func receivableContextMenu(_ receivable: Receivable) -> some View {
        if receivable.isPending {
            Button {
                openReceivable(receivable)
            } label: {
                Label("Confirmar recebimento", systemImage: "checkmark.circle")
            }
            Button {
                reschedulingReceivable = receivable
            } label: {
                Label("Reagendar", systemImage: "calendar.badge.clock")
            }
            Button {
                receivable.status = .cancelled
                ReceivableNotifications.cancel(for: receivable)
            } label: {
                Label("Cancelar recebível", systemImage: "xmark.circle")
            }
        }
        Button {
            editingReceivable = receivable
        } label: {
            Label("Editar", systemImage: "pencil")
        }
        if receivable.isPending, aiService.configuration.isReady {
            Button {
                chatPanelState.openToDiscussReceivable(receivable)
            } label: {
                Label("Conversar com \(AIAssistantIdentity.name)", systemImage: "sparkles")
            }
        }
        Button(role: .destructive) {
            ReceivableNotifications.cancel(for: receivable)
            modelContext.delete(receivable)
        } label: {
            Label("Excluir", systemImage: "trash")
        }
    }

    private func openReceivable(_ receivable: Receivable) {
        if receivable.isPending {
            confirmingReceivable = receivable
        } else {
            editingReceivable = receivable
        }
    }

    private func rowContent(_ receivable: Receivable) -> some View {
        CFGlassAmountRow(
            systemName: rowSymbol(for: receivable),
            tint: rowTint(for: receivable),
            title: receivable.name,
            subtitle: subtitle(for: receivable),
            amount: receivable.amount.brl,
            amountColor: receivable.isReceived ? Color.secondary : CFTheme.income,
            trailingCaption: receivable.account?.name,
            dimmed: receivable.isReceived
        )
    }

    private func rowSymbol(for receivable: Receivable) -> String {
        receivable.category?.symbolName ?? "tray.and.arrow.down"
    }

    private func rowTint(for receivable: Receivable) -> Color {
        if receivable.isReceived { return CFTheme.income }
        if receivable.isLate() { return CFTheme.warning }
        return CFTheme.accent
    }

    private func subtitle(for receivable: Receivable) -> String {
        if receivable.isReceived, let receivedOn = receivable.receivedOn {
            return "Recebido \(receivedOn.cfRelativeOrAbsoluteDay())"
        }
        let expected = receivable.expectedDate.cfRelativeOrAbsoluteDay()
        if receivable.isLate() {
            return "Esperado \(expected)"
        }
        return "Previsto \(expected)"
    }
}
