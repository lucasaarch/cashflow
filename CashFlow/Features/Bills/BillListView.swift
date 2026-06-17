import SwiftUI
import SwiftData

struct BillListView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [SortDescriptor(\Bill.dueDate)])
    private var bills: [Bill]

    @State private var showingAdd = false
    @State private var editingBill: Bill?
    @State private var payingBill: Bill?
    @State private var payingInvoiceBill: Bill?
    @State private var searchText = ""

    private var filteredBills: [Bill] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let visible = bills.filter { $0.status != .cancelled }
        if query.isEmpty { return visible }
        return visible.filter { $0.name.lowercased().contains(query) }
    }

    private var overdue: [Bill] {
        filteredBills.filter { $0.isOverdue() }
    }

    private var upcoming: [Bill] {
        filteredBills.filter { $0.isPending && !$0.isOverdue() }
    }

    private var paid: [Bill] {
        filteredBills.filter { $0.isPaid }
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
        .searchable(text: $searchText, placement: .toolbar, prompt: "Buscar por nome")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Nova conta", systemImage: "plus")
                }
                .help("Cadastrar conta a pagar")
            }
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
        .onAppear {
            CardStatementMaterializer.materializeAll(context: modelContext)
        }
        .cfPageBackground()
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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !overdue.isEmpty {
                    section(title: "Vencidas", tint: CFTheme.danger, bills: overdue)
                }
                if !upcoming.isEmpty {
                    section(title: "A vencer", tint: CFTheme.warning, bills: upcoming)
                }
                if !paid.isEmpty {
                    section(title: "Pagas", tint: CFTheme.income, bills: paid)
                }
            }
            .padding(20)
        }
    }

    private func section(title: String, tint: Color, bills: [Bill]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                    .textCase(.uppercase)
                Text("\(bills.count)")
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(tint.opacity(0.15)))
            }
            .padding(.horizontal, 2)

            ForEach(bills) { bill in
                CFHoverRow {
                    rowContent(bill)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    openBill(bill)
                }
                .contextMenu {
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
                    Button(role: .destructive) {
                        BillNotifications.cancel(for: bill)
                        modelContext.delete(bill)
                    } label: {
                        Label("Excluir", systemImage: "trash")
                    }
                }
            }
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
        HStack(spacing: 12) {
            CFIconBadge(
                symbolName: rowSymbol(for: bill),
                tint: rowTint(for: bill),
                size: 30
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(bill.name)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(subtitle(for: bill))
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(bill.amount.brl)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(bill.isPaid ? CFTheme.textSecondary : CFTheme.textPrimary)
                if let trailingAccount = bill.cardStatementSource ?? bill.account {
                    Text(trailingAccount.name)
                        .font(.caption2)
                        .foregroundStyle(CFTheme.textTertiary)
                }
            }
        }
        .opacity(bill.isPaid ? 0.7 : 1)
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
        let formatter = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Money.locale)
        if bill.isPaid, let paid = bill.paidOn {
            return bill.isCardStatement
                ? "Fatura paga em \(paid.formatted(formatter))"
                : "Paga em \(paid.formatted(formatter))"
        }
        if bill.isOverdue() {
            return "Venceu \(bill.dueDate.formatted(formatter))"
        }
        if bill.isCardStatement {
            return "Fatura · vence \(bill.dueDate.formatted(formatter))"
        }
        return "Vence \(bill.dueDate.formatted(formatter))"
    }
}
