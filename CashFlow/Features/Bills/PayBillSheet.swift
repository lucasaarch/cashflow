import SwiftUI
import SwiftData

/// Quick "mark as paid" flow. Lets the user adjust the actual amount and date
/// (often differs from the expected). Generates a `Transaction` linked to the
/// `Bill` via `paidTransactionID`.
struct PayBillSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    let bill: Bill

    @State private var paidAmount: Decimal
    @State private var paidDate: Date
    @State private var accountID: UUID?

    init(bill: Bill) {
        self.bill = bill
        _paidAmount = State(initialValue: bill.amount)
        _paidDate = State(initialValue: .now)
        _accountID = State(initialValue: bill.account?.id)
    }

    private var spendableAccounts: [Account] {
        accounts.filter { $0.kind == .bank || $0.kind == .creditCard }
    }

    private var isValid: Bool {
        paidAmount > 0 && accountID != nil
    }

    private var differenceCaption: String? {
        guard paidAmount != bill.amount, bill.amount > 0 else { return nil }
        let delta = paidAmount - bill.amount
        let prefix = delta > 0 ? "+" : "−"
        return "\(prefix)\(abs(delta).brl) em relação ao previsto"
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 460, height: 480)
        .cfCompactSheetToolbar(
            title: "Pagar conta",
            saveTitle: "Confirmar",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { confirm(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfGlassSheetChrome()
    }

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(spacing: 8) {
                        CFGlassSheetAmountHeader(
                            title: "Valor pago",
                            amount: $paidAmount,
                            amountColor: CFTheme.expense
                        )
                        if let caption = differenceCaption {
                            Text(caption)
                                .font(.callout)
                                .foregroundStyle(CFTheme.warning)
                                .padding(.horizontal, 4)
                        }
                    }

                    infoCard

                    CFGlassFormPanel(title: "Pagamento") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Conta") { accountPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Data") {
                                DateField(date: $paidDate)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    private var infoCard: some View {
        CFGlassPanel {
            HStack(spacing: 12) {
                CFIconBadge(
                    symbolName: bill.category?.symbolName ?? "doc.text",
                    tint: CFTheme.expense,
                    size: 32
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(bill.name)
                        .font(.body)
                    Text(dueCaption)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(bill.amount.brl)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
            .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
        }
    }

    private var dueCaption: String {
        let formatter = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Money.locale)
        let dueText = bill.dueDate.formatted(formatter)
        return bill.isOverdue() ? "Venceu \(dueText)" : "Vence \(dueText)"
    }

    @ViewBuilder
    private var accountPicker: some View {
        CFSelectFieldOptional(
            selection: $accountID,
            options: spendableAccounts.map { account in
                CFSelectOption(
                    id: account.id,
                    title: account.name,
                    symbolName: account.symbolName,
                    tint: Color(hex: account.colorHex)
                )
            },
            placeholder: "Selecionar"
        )
    }

    private var footer: some View {
        CFGlassSheetFooter(
            confirmTitle: "Confirmar pagamento",
            confirmDisabled: !isValid,
            onCancel: { dismiss() },
            onConfirm: { confirm(); dismiss() }
        )
    }

    private func confirm() {
        guard isValid,
              let accountID,
              let account = spendableAccounts.first(where: { $0.id == accountID })
        else { return }

        let normalizedDate = Calendar.current.startOfDay(for: paidDate)
        let memo = bill.note.isEmpty ? bill.name : "\(bill.name) — \(bill.note)"

        let txn = Transaction(
            amount: paidAmount,
            kind: .expense,
            occurredOn: normalizedDate,
            note: memo,
            category: bill.category,
            account: account
        )
        modelContext.insert(txn)

        bill.status = .paid
        bill.paidOn = normalizedDate
        bill.paidTransactionID = txn.id
        BillNotifications.cancel(for: bill)
    }
}
