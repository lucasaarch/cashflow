import SwiftUI
import SwiftData

enum InvestmentDirection: String, CaseIterable, Identifiable {
    case deposit
    case withdraw

    var id: String { rawValue }
    var label: String {
        switch self {
        case .deposit:  return "Aportar"
        case .withdraw: return "Resgatar"
        }
    }

    var fundDirection: FundTransferDirection {
        switch self {
        case .deposit: return .deposit
        case .withdraw: return .withdraw
        }
    }
}

struct InvestmentTransferSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    let investmentAccount: Account

    @State private var direction: InvestmentDirection = .deposit
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
            return "Sairá de \(bankName) e entrará em \(investmentAccount.name)."
        case .withdraw:
            return "Sairá de \(investmentAccount.name) e entrará em \(bankName)."
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
        .cfAdaptiveSheetFrame(width: 480, height: 460)
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
            ForEach(InvestmentDirection.allCases) { option in
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
                    labeledRow("Data") {
                        DateField(date: $occurredOn)
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
            fundAccount: investmentAccount,
            note: note
        )
    }
}
