import SwiftUI
import SwiftData

/// Quick "confirm received" flow. Lets the user adjust the actual amount and date
/// (often differs from the expected). Generates a `Transaction(kind: .income)`
/// linked to the `Receivable` via `receivedTransactionID`.
struct ConfirmReceivableSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    let receivable: Receivable

    @State private var receivedAmount: Decimal
    @State private var receivedDate: Date
    @State private var accountID: UUID?

    init(receivable: Receivable) {
        self.receivable = receivable
        _receivedAmount = State(initialValue: receivable.amount)
        _receivedDate = State(initialValue: .now)
        _accountID = State(initialValue: receivable.account?.id)
    }

    private var depositAccounts: [Account] {
        accounts.filter { $0.kind != .creditCard }
    }

    private var isValid: Bool {
        receivedAmount > 0 && accountID != nil
    }

    private var differenceCaption: String? {
        guard receivedAmount != receivable.amount, receivable.amount > 0 else { return nil }
        let delta = receivedAmount - receivable.amount
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
            title: "Confirmar recebimento",
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
                            title: "Valor recebido",
                            amount: $receivedAmount,
                            amountColor: CFTheme.income
                        )
                        if let caption = differenceCaption {
                            Text(caption)
                                .font(.callout)
                                .foregroundStyle(receivedAmount >= receivable.amount ? CFTheme.income : CFTheme.warning)
                                .padding(.horizontal, 4)
                        }
                    }

                    infoCard

                    CFGlassFormPanel(title: "Recebimento") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Conta") { accountPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Data") {
                                DateField(date: $receivedDate)
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
                    symbolName: receivable.category?.symbolName ?? "tray.and.arrow.down",
                    tint: CFTheme.income,
                    size: 32
                )
                VStack(alignment: .leading, spacing: 1) {
                    Text(receivable.name)
                        .font(.body)
                    Text(expectedCaption)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(receivable.amount.brl)
                    .font(.callout.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
            .padding(.vertical, CFGlassMetrics.rowVerticalPadding)
        }
    }

    private var expectedCaption: String {
        let formatter = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Money.locale)
        let dateText = receivable.expectedDate.formatted(formatter)
        return receivable.isLate() ? "Esperado \(dateText)" : "Previsto \(dateText)"
    }

    @ViewBuilder
    private var accountPicker: some View {
        CFSelectFieldOptional(
            selection: $accountID,
            options: depositAccounts.map { account in
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
            confirmTitle: "Confirmar recebimento",
            confirmDisabled: !isValid,
            onCancel: { dismiss() },
            onConfirm: { confirm(); dismiss() }
        )
    }

    private func confirm() {
        guard isValid,
              let accountID,
              let account = depositAccounts.first(where: { $0.id == accountID })
        else { return }

        let normalizedDate = Calendar.current.startOfDay(for: receivedDate)
        let memo = receivable.note.isEmpty ? receivable.name : "\(receivable.name) — \(receivable.note)"

        let txn = Transaction(
            amount: receivedAmount,
            kind: .income,
            occurredOn: normalizedDate,
            note: memo,
            category: receivable.category,
            account: account
        )
        modelContext.insert(txn)

        receivable.status = .received
        receivable.receivedOn = normalizedDate
        receivable.receivedTransactionID = txn.id
        ReceivableNotifications.cancel(for: receivable)
    }
}
