import SwiftUI
import SwiftData

struct ReceivableListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var privacy: PrivacyMode

    @Query(sort: [SortDescriptor(\Receivable.expectedDate)])
    private var receivables: [Receivable]

    @State private var showingAdd = false
    @State private var editingReceivable: Receivable?
    @State private var confirmingReceivable: Receivable?
    @State private var reschedulingReceivable: Receivable?
    @State private var searchText = ""

    private var filteredReceivables: [Receivable] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let visible = receivables.filter { $0.status != .cancelled }
        if query.isEmpty { return visible }
        return visible.filter { $0.name.lowercased().contains(query) }
    }

    private var late: [Receivable] {
        filteredReceivables.filter { $0.isLate() }
    }

    private var upcoming: [Receivable] {
        filteredReceivables.filter { $0.isPending && !$0.isLate() }
    }

    private var received: [Receivable] {
        filteredReceivables.filter { $0.isReceived }
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
        .searchable(text: $searchText, placement: .toolbar, prompt: "Buscar por nome")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Novo recebível", systemImage: "plus")
                }
                .help("Cadastrar conta a receber")
            }
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
        .cfPageBackground()
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
        CFScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !late.isEmpty {
                    section(title: "Atrasadas", tint: CFTheme.warning, items: late)
                }
                if !upcoming.isEmpty {
                    section(title: "A receber", tint: CFTheme.accent, items: upcoming)
                }
                if !received.isEmpty {
                    section(title: "Recebidas", tint: CFTheme.income, items: received)
                }
            }
            .padding(20)
        }
    }

    private func section(title: String, tint: Color, items: [Receivable]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                    .textCase(.uppercase)
                Text("\(items.count)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(tint.opacity(0.15)))
            }
            .padding(.horizontal, 2)

            ForEach(items) { receivable in
                CFHoverRow {
                    rowContent(receivable)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    openReceivable(receivable)
                }
                .contextMenu {
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
                    Button(role: .destructive) {
                        ReceivableNotifications.cancel(for: receivable)
                        modelContext.delete(receivable)
                    } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                }
            }
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
        HStack(spacing: 12) {
            CFIconBadge(
                symbolName: rowSymbol(for: receivable),
                tint: rowTint(for: receivable),
                size: 30
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(receivable.name)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(subtitle(for: receivable))
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(receivable.amount.brl(masked: privacy.valuesHidden))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(receivable.isReceived ? CFTheme.textSecondary : CFTheme.income)
                if let account = receivable.account {
                    Text(account.name)
                        .font(.caption2)
                        .foregroundStyle(CFTheme.textTertiary)
                }
            }
        }
        .opacity(receivable.isReceived ? 0.7 : 1)
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
