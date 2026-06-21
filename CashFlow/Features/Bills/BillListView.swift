import SwiftUI
import SwiftData

struct BillListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var chatPanelState: AIChatPanelState
    @EnvironmentObject private var aiService: AIService
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif

    @Query(sort: [SortDescriptor(\Bill.dueDate)])
    private var bills: [Bill]

    @State private var showingAdd = false
    @State private var editingBill: Bill?
    @State private var payingBill: Bill?
    @State private var payingInvoiceBill: Bill?
    @State private var reschedulingBill: Bill?
    #if os(macOS)
    @State private var highlightedBillID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif

    private var visibleBills: [Bill] {
        bills.filter { $0.status != .cancelled }
    }

    private var overdue: [Bill] {
        visibleBills.filter { $0.isOverdue() }
    }

    private var upcoming: [Bill] {
        visibleBills.filter { $0.isPending && !$0.isOverdue() }
    }

    private var paid: [Bill] {
        visibleBills.filter { $0.isPaid }
            .sorted { ($0.paidOn ?? .distantPast) > ($1.paidOn ?? .distantPast) }
    }

    var body: some View {
        Group {
            if bills.filter({ $0.status != .cancelled }).isEmpty {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Contas a pagar")
        .detailToolbarAdd(help: "Cadastrar conta a pagar") {
            showingAdd = true
        }
        .sheet(isPresented: $showingAdd) {
            AddBillSheet()
        }
        .sheet(item: $editingBill) { bill in
            AddBillSheet(editing: bill)
        }
        .sheet(item: $payingBill) { bill in
            PayBillSheet(bill: bill)
        }
        .sheet(item: $payingInvoiceBill) { bill in
            if let card = bill.cardStatementSource {
                PayInvoiceSheet(card: card, maxAmount: bill.amount, linkedBill: bill)
            }
        }
        .sheet(item: $reschedulingBill) { bill in
            RescheduleSheet(
                title: "Reagendar vencimento",
                subtitle: bill.name,
                initialDate: bill.dueDate
            ) { newDate in
                bill.dueDate = Calendar.current.startOfDay(for: newDate)
                BillNotifications.schedule(for: bill)
            }
        }
        .onAppear {
            Task { @MainActor in
                CardStatementMaterializer.materializeAll(context: modelContext)
            }
        }
        .cfGlassDetailChrome()
    }

    private var billSections: [(title: String, tint: Color, bills: [Bill])] {
        var sections: [(String, Color, [Bill])] = []
        if !overdue.isEmpty { sections.append(("Vencidas", CFTheme.danger, overdue)) }
        if !upcoming.isEmpty { sections.append(("A vencer", CFTheme.warning, upcoming)) }
        if !paid.isEmpty { sections.append(("Pagas", CFTheme.income, paid)) }
        return sections
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "calendar.badge.clock",
            title: "Sem contas pendentes",
            message: "Cadastre boletos, IPTU, mensalidades — qualquer despesa que precisa confirmação manual quando paga.",
            actionTitle: "Cadastrar conta"
        ) {
            showingAdd = true
        }
    }

    private var content: some View {
        ScrollViewReader { proxy in
            CFGlassPage {
                CFGlassPageStack {
                    ForEach(Array(billSections.enumerated()), id: \.offset) { index, section in
                        billSection(
                            title: section.title,
                            tint: section.tint,
                            bills: section.bills,
                            staggerIndex: index
                        )
                    }
                }
            }
            #if os(macOS)
            .spotlightScrollTarget(
                navigation: spotlightNavigation,
                kind: .bill,
                highlightedID: $highlightedBillID,
                focusTask: $spotlightFocusTask,
                proxy: proxy,
                onReveal: { id in
                    if let bill = bills.first(where: { $0.id == id }) {
                        openBill(bill)
                    }
                }
            )
            #endif
        }
    }

    private func billSection(
        title: String,
        tint: Color,
        bills: [Bill],
        staggerIndex: Int
    ) -> some View {
        CFGlassSection(
            title: title,
            count: bills.count,
            countTint: tint,
            staggerIndex: staggerIndex
        ) {
            CFGlassEnumeratedPanel(items: bills) { bill, _ in
                CFGlassRowButton {
                    openBill(bill)
                } label: {
                    rowContent(bill)
                }
                .id(bill.id)
                #if os(macOS)
                .spotlightFocused(highlightedBillID == bill.id)
                #endif
                .contextMenu {
                    billContextMenu(bill)
                }
            }
        }
    }

    @ViewBuilder
    private func billContextMenu(_ bill: Bill) -> some View {
        if bill.isPending {
            Button {
                openBill(bill)
            } label: {
                Label(
                    bill.isCardStatement ? "Pagar fatura" : "Marcar como paga",
                    systemImage: bill.isCardStatement ? "creditcard.and.123" : "checkmark.circle"
                )
            }
            if !bill.isCardStatement {
                Button {
                    reschedulingBill = bill
                } label: {
                    Label("Reagendar", systemImage: "calendar.badge.clock")
                }
                Button {
                    bill.status = .cancelled
                    BillNotifications.cancel(for: bill)
                } label: {
                    Label("Cancelar conta", systemImage: "xmark.circle")
                }
            }
        }
        if !bill.isCardStatement {
            Button {
                editingBill = bill
            } label: {
                Label("Editar", systemImage: "pencil")
            }
        }
        if bill.isPending, aiService.configuration.isReady {
            Button {
                chatPanelState.openToDiscussBill(bill)
            } label: {
                Label("Conversar com \(AIAssistantIdentity.name)", systemImage: "sparkles")
            }
        }
        Button(role: .destructive) {
            BillNotifications.cancel(for: bill)
            modelContext.delete(bill)
        } label: {
            Label("Excluir", systemImage: "trash")
        }
    }

    private func openBill(_ bill: Bill) {
        guard bill.isPending else {
            if !bill.isCardStatement {
                editingBill = bill
            }
            return
        }
        if bill.isCardStatement {
            payingInvoiceBill = bill
        } else {
            payingBill = bill
        }
    }

    private func rowContent(_ bill: Bill) -> some View {
        CFGlassAmountRow(
            systemName: rowSymbol(for: bill),
            tint: rowTint(for: bill),
            title: bill.name,
            subtitle: subtitle(for: bill),
            amount: bill.amount.brl,
            amountColor: bill.isPaid ? Color.secondary : Color.primary,
            trailingCaption: (bill.cardStatementSource ?? bill.account)?.name,
            dimmed: bill.isPaid
        )
    }

    private func rowSymbol(for bill: Bill) -> String {
        if bill.isCardStatement {
            return bill.cardStatementSource?.symbolName ?? "creditcard.fill"
        }
        return bill.category?.symbolName ?? "doc.text"
    }

    private func rowTint(for bill: Bill) -> Color {
        if bill.isPaid { return CFTheme.income }
        if bill.isOverdue() { return CFTheme.danger }
        if bill.isCardStatement { return CFTheme.debt }
        return CFTheme.expense
    }

    private func subtitle(for bill: Bill) -> String {
        if bill.isPaid, let paid = bill.paidOn {
            let when = paid.cfRelativeOrAbsoluteDay()
            return bill.isCardStatement ? "Fatura paga \(when)" : "Paga \(when)"
        }
        let due = bill.dueDate.cfRelativeOrAbsoluteDay()
        if bill.isOverdue() {
            return "Venceu \(due)"
        }
        if bill.isCardStatement {
            return "Fatura · vence \(due)"
        }
        return "Vence \(due)"
    }
}
