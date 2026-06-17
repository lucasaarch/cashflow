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
        accounts.filter { $0.kind != .investment }
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
            CFAmountHeader(
                title: "Valor pago",
                amount: $paidAmount,
                amountColor: CFTheme.expense
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if let caption = differenceCaption {
                Text(caption)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.warning)
                    .padding(.bottom, 14)
            } else {
                Spacer().frame(height: 8)
            }

            Divider()
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 460, height: 440)
        .cfCompactSheetToolbar(
            title: "Pagar conta",
            saveTitle: "Confirmar",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { confirm(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                infoCard
                section(title: "Pagamento") {
                    labeledRow("Conta") { accountPicker }
                    labeledRow("Data") {
                        DateField(date: $paidDate)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
    }

    private var infoCard: some View {
        HStack(spacing: 12) {
            CFIconBadge(
                symbolName: bill.category?.symbolName ?? "doc.text",
                tint: CFTheme.expense,
                size: 32
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(bill.name)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(dueCaption)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
            Text(bill.amount.brl)
                .font(.callout.monospacedDigit())
                .foregroundStyle(CFTheme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.5))
        )
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

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)
            VStack(spacing: 6) {
                content()
            }
        }
    }

    private func labeledRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textSecondary)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CFTheme.surfaceElevated.opacity(0.38))
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            CFPillButton(title: "Cancelar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            CFPillButton(title: "Confirmar pagamento", style: .primary) {
                confirm()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .opacity(isValid ? 1 : 0.5)
            .allowsHitTesting(isValid)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
