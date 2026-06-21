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
        .cfGlassSheetChrome()
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
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    CFGlassSheetAmountHeader(
                        title: direction == .deposit ? "Valor do aporte" : "Valor do resgate",
                        amount: $amount,
                        amountColor: CFTheme.accent
                    )

                    directionPicker

                    CFGlassFormPanel(title: direction == .deposit ? "Origem" : "Destino") {
                        CFGlassLabeledField(label: "Conta bancária") { bankPicker }
                    }

                    CFGlassFormPanel(title: direction == .deposit ? "Destino" : "Origem") {
                        CFGlassLabeledField(label: "Fundo") { fundPicker }
                    }

                    CFGlassFormPanel(title: "Detalhes") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Data") {
                                DateField(date: $occurredOn)
                            }
                            if isPlanned {
                                Text("Lançamento previsto — será contabilizado quando a data chegar.")
                                    .font(.callout)
                                    .foregroundStyle(CFTheme.warning)
                                    .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                                    .padding(.bottom, CFGlassMetrics.rowVerticalPadding)
                            }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Nota") {
                                TextField("Opcional", text: $note)
                                    .textFieldStyle(.plain)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }

                    Text(summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
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

    private var footer: some View {
        CFGlassSheetFooter(
            confirmTitle: "Confirmar",
            confirmDisabled: !isValid,
            onCancel: { dismiss() },
            onConfirm: { save(); dismiss() }
        )
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
