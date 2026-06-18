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
            CFAmountHeader(
                title: "Valor recebido",
                amount: $receivedAmount,
                amountColor: CFTheme.income
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            if let caption = differenceCaption {
                Text(caption)
                    .font(CFTheme.caption())
                    .foregroundStyle(receivedAmount >= receivable.amount ? CFTheme.income : CFTheme.warning)
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
            title: "Confirmar recebimento",
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
                section(title: "Recebimento") {
                    labeledRow("Conta") { accountPicker }
                    labeledRow("Data") {
                        DateField(date: $receivedDate)
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
                symbolName: receivable.category?.symbolName ?? "tray.and.arrow.down",
                tint: CFTheme.income,
                size: 32
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(receivable.name)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(expectedCaption)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
            Text(receivable.amount.brl)
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
            CFPillButton(title: "Confirmar recebimento", style: .primary) {
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
    }
}
