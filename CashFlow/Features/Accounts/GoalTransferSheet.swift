import SwiftUI
import SwiftData

enum GoalTransferDirection: String, CaseIterable, Identifiable {
    case deposit
    case withdraw

    var id: String { rawValue }
    var label: String {
        switch self {
        case .deposit:  return "Depositar"
        case .withdraw: return "Retirar"
        }
    }

    var fundDirection: FundTransferDirection {
        switch self {
        case .deposit: return .deposit
        case .withdraw: return .withdraw
        }
    }
}

/// Moves money between a bank account and a goal-kind account. Records both legs as
/// a single transfer (shared `transferGroupID`) so they don't inflate the month's
/// income/expense totals — same pattern used by `InvestmentTransferSheet`.
struct GoalTransferSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    let goalAccount: Account

    @State private var direction: GoalTransferDirection = .deposit
    @State private var amount: Decimal = 0
    @State private var occurredOn: Date = .now
    @State private var bankAccountID: UUID?
    @State private var note: String = ""

    private var bankAccounts: [Account] {
        accounts.filter { $0.kind == .bank }
    }

    private var isValid: Bool {
        amount > 0 && bankAccountID != nil
    }

    private var summary: String {
        let bankName = bankAccounts.first(where: { $0.id == bankAccountID })?.name ?? "conta"
        switch direction {
        case .deposit:
            return "Sairá de \(bankName) e entrará em \(goalAccount.name)."
        case .withdraw:
            return "Sairá de \(goalAccount.name) e entrará em \(bankName)."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 480, height: 460)
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
            ForEach(GoalTransferDirection.allCases) { option in
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
                        title: direction == .deposit ? "Valor a depositar" : "Valor a retirar",
                        amount: $amount,
                        amountColor: CFTheme.accent
                    )

                    directionPicker

                    CFGlassFormPanel(title: direction == .deposit ? "Origem" : "Destino") {
                        VStack(spacing: 0) {
                            CFGlassLabeledField(label: "Conta bancária") { bankPicker }
                            CFGlassPanelDivider()
                            CFGlassLabeledField(label: "Data") {
                                DateField(date: $occurredOn)
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

    private var footer: some View {
        CFGlassSheetFooter(
            confirmTitle: "Confirmar",
            confirmDisabled: !isValid,
            onCancel: { dismiss() },
            onConfirm: { save(); dismiss() }
        )
    }

    private func prefillDefaults() {
        if bankAccountID == nil {
            bankAccountID = bankAccounts.first?.id
        }
    }

    private func save() {
        guard isValid,
              let bankAccountID,
              let bankAccount = bankAccounts.first(where: { $0.id == bankAccountID })
        else { return }

        FundTransferRecorder.record(
            in: modelContext,
            direction: direction.fundDirection,
            amount: amount,
            occurredOn: occurredOn,
            bankAccount: bankAccount,
            fundAccount: goalAccount,
            note: note
        )
    }
}
