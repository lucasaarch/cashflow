import SwiftUI
import SwiftData

struct FundTransferSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    var preselectedFundID: UUID?
    var initialDirection: FundTransferDirection = .deposit

    @State private var direction: FundTransferDirection = .deposit
    @State private var amount: Decimal = 0
    @State private var occurredOn: Date = .now
    @State private var bankAccountID: UUID?
    @State private var fundAccountID: UUID?
    @State private var note: String = ""

    private var bankAccounts: [Account] {
        accounts.filter { $0.kind == .bank }
    }

    private var fundAccounts: [Account] {
        accounts.filter { $0.kind == .investment || $0.kind == .goal }
    }

    private var selectedFund: Account? {
        guard let fundAccountID else { return nil }
        return fundAccounts.first { $0.id == fundAccountID }
    }

    private var isValid: Bool {
        amount > 0 && bankAccountID != nil && fundAccountID != nil
    }

    private var isPlanned: Bool {
        occurredOn > Calendar.current.startOfDay(for: .now)
    }

    private var summary: String {
        let bankName = bankAccounts.first(where: { $0.id == bankAccountID })?.name ?? "conta bancária"
        let fundName = selectedFund?.name ?? "fundo"
        let planned = isPlanned ? " (previsto)" : ""
        switch direction {
        case .deposit:
            return "Sairá de \(bankName) e entrará em \(fundName)\(planned)."
        case .withdraw:
            return "Sairá de \(fundName) e entrará em \(bankName)\(planned)."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            CFAmountHeader(
                title: direction == .deposit ? "Valor do aporte" : "Valor do resgate",
                amount: $amount,
                amountColor: CFTheme.accent
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 8)

            directionPicker
                .padding(.horizontal, 20)
                .padding(.bottom, 14)

            Divider()
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 520)
        .cfCompactSheetToolbar(
            title: "Transferir",
            saveDisabled: !isValid,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
        .onAppear(perform: prefillDefaults)
    }

    private var directionPicker: some View {
        Picker("Direção", selection: $direction) {
            ForEach(FundTransferDirection.allCases) { option in
                Text(option.label).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section(title: direction == .deposit ? "Origem" : "Destino") {
                    labeledRow("Conta bancária") {
                        bankPicker
                    }
                }

                section(title: direction == .deposit ? "Destino" : "Origem") {
                    labeledRow("Fundo") {
                        fundPicker
                    }
                }

                section(title: "Detalhes") {
                    labeledRow("Data") {
                        DateField(date: $occurredOn)
                    }
                    if isPlanned {
                        Text("Lançamento previsto — será contabilizado quando a data chegar.")
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.warning)
                            .padding(.horizontal, 4)
                    }
                    labeledRow("Nota") {
                        TextField("Opcional", text: $note)
                            .textFieldStyle(.plain)
                            .font(CFTheme.body())
                            .multilineTextAlignment(.trailing)
                    }
                }

                Text(summary)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .cfScrollContent()
        }
        .cfScrollChrome()
    }

    @ViewBuilder
    private var bankPicker: some View {
        CFSelectFieldOptional(
            selection: $bankAccountID,
            options: bankAccounts.map { account in
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

    @ViewBuilder
    private var fundPicker: some View {
        CFSelectFieldOptional(
            selection: $fundAccountID,
            options: fundAccounts.map { account in
                CFSelectOption(
                    id: account.id,
                    title: "\(account.name) · \(account.kind.displayName)",
                    symbolName: account.symbolName,
                    tint: Color(hex: account.colorHex)
                )
            },
            placeholder: "Selecionar"
        )
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
            content()
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
            CFPillButton(title: "Confirmar", style: .primary) {
                save()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .opacity(isValid ? 1 : 0.5)
            .allowsHitTesting(isValid)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func prefillDefaults() {
        direction = initialDirection
        if bankAccountID == nil {
            bankAccountID = bankAccounts.first?.id
        }
        if fundAccountID == nil {
            fundAccountID = preselectedFundID ?? fundAccounts.first?.id
        }
    }

    private func save() {
        guard isValid,
              let bankAccountID,
              let fundAccountID,
              let bankAccount = bankAccounts.first(where: { $0.id == bankAccountID }),
              let fundAccount = fundAccounts.first(where: { $0.id == fundAccountID })
        else { return }

        FundTransferRecorder.record(
            in: modelContext,
            direction: direction,
            amount: amount,
            occurredOn: occurredOn,
            bankAccount: bankAccount,
            fundAccount: fundAccount,
            note: note
        )
    }
}
