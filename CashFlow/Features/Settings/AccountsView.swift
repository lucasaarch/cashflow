import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Account.sortOrder)]) private var accounts: [Account]
    @Query private var transactions: [Transaction]

    @State private var showingAdd = false
    @State private var editingAccount: Account?
    @State private var invoiceAccount: Account?
    @State private var transferAccount: Account?

    var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    var archivedAccounts: [Account] {
        accounts.filter { $0.isArchived }
    }

    /// Order of sections on the screen.
    private let groupOrder: [AccountKind] = [.bank, .creditCard, .investment]

    private func activeAccounts(of kind: AccountKind) -> [Account] {
        activeAccounts.filter { $0.kind == kind }
    }

    private func sectionTitle(for kind: AccountKind) -> String {
        switch kind {
        case .bank:       return "Contas"
        case .creditCard: return "Cartões"
        case .investment: return "Investimentos"
        }
    }

    var body: some View {
        Group {
            if accounts.isEmpty {
                emptyState
            } else {
                accountList
            }
        }
        .navigationTitle("Contas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Nova conta", systemImage: "plus")
                }
                .help("Nova conta")
            }
        }
        .sheet(isPresented: $showingAdd) {
            AccountSheet()
        }
        .sheet(item: $editingAccount) { account in
            AccountSheet(editing: account)
        }
        .sheet(item: $invoiceAccount) { account in
            CardInvoiceSheet(account: account)
        }
        .sheet(item: $transferAccount) { account in
            InvestmentTransferSheet(investmentAccount: account)
        }
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "wallet.pass",
            title: "Nenhuma conta cadastrada",
            message: "Conta é onde seu dinheiro mora: sua conta corrente, dinheiro vivo, cartão da namorada (dívida). Não confunda com categorias de gasto.",
            actionTitle: "Criar primeira conta"
        ) {
            showingAdd = true
        }
    }

    private var accountList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groupOrder, id: \.self) { kind in
                    let kindAccounts = activeAccounts(of: kind)
                    if !kindAccounts.isEmpty {
                        kindSection(kind: kind, accounts: kindAccounts)
                    }
                }

                if !archivedAccounts.isEmpty {
                    archivedSection
                }
            }
            .padding(20)
        }
        .cfPageBackground()
    }

    private func kindSection(kind: AccountKind, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionTitle(for: kind))
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(accounts) { account in
                let balance = account.currentBalance(considering: transactions)
                CFHoverRow {
                    accountRowContent(account, balance: balance)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    switch account.kind {
                    case .creditCard:
                        invoiceAccount = account
                    case .investment:
                        transferAccount = account
                    case .bank:
                        editingAccount = account
                    }
                }
                .contextMenu {
                    if account.kind == .creditCard {
                        Button {
                            invoiceAccount = account
                        } label: {
                            Label("Ver fatura", systemImage: "doc.text")
                        }
                    }
                    if account.kind == .investment {
                        Button {
                            transferAccount = account
                        } label: {
                            Label("Aportar / Resgatar", systemImage: "arrow.left.arrow.right")
                        }
                    }
                    Button {
                        editingAccount = account
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        account.isArchived = true
                    } label: {
                        Label("Arquivar", systemImage: "archivebox")
                    }
                }
            }
        }
    }

    private var archivedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Arquivadas")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(archivedAccounts) { account in
                CFHoverRow {
                    HStack(spacing: 12) {
                        accountBadge(account, muted: true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(account.name)
                                .font(CFTheme.body())
                                .foregroundStyle(CFTheme.textSecondary)
                            Text(account.kind.displayName)
                                .font(CFTheme.caption())
                                .foregroundStyle(CFTheme.textTertiary)
                        }
                        Spacer()
                        Button("Restaurar") {
                            account.isArchived = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
        }
    }

    private func accountRowContent(_ account: Account, balance: Decimal) -> some View {
        HStack(spacing: 12) {
            accountBadge(account, muted: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.name)
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textPrimary)
                Text(accountSubtitle(account))
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                CFAnimatedAmount(
                    amount: displayedBalance(for: account, balance: balance),
                    font: .callout.monospacedDigit().weight(.medium),
                    color: balanceColor(for: account, balance: balance)
                )
                Text(balanceCaption(for: account, balance: balance))
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(CFTheme.textTertiary)
        }
    }

    private func accountSubtitle(_ account: Account) -> String {
        if account.kind == .creditCard {
            let statement = account.openStatement(considering: transactions)
            if let due = statement.dueDate, statement.totalDebt > 0 {
                let dueText = due.formatted(.dateTime.day().month(.abbreviated).locale(Money.locale))
                return "Vence \(dueText)"
            }
            if let billing = account.billingCycleCaption {
                return billing
            }
            return "Cartão"
        }
        return account.kind.displayName
    }

    private func balanceColor(for account: Account, balance: Decimal) -> Color {
        switch account.kind {
        case .bank:
            return balance < 0 ? CFTheme.danger : CFTheme.textPrimary
        case .creditCard:
            return CFTheme.debt
        case .investment:
            return CFTheme.accent
        }
    }

    private func displayedBalance(for account: Account, balance: Decimal) -> Decimal {
        switch account.kind {
        case .bank, .investment:
            return balance
        case .creditCard:
            return abs(balance)
        }
    }

    private func balanceCaption(for account: Account, balance: Decimal) -> String {
        switch account.kind {
        case .bank:
            return "Saldo atual"
        case .creditCard:
            if balance < 0 { return "A pagar" }
            if balance == 0 { return "Fatura zerada" }
            return "Crédito"
        case .investment:
            return "Investido"
        }
    }

    private func accountBadge(_ account: Account, muted: Bool) -> some View {
        let tint = muted ? CFTheme.textSecondary : Color(hex: account.colorHex)
        return CFIconBadge(symbolName: account.symbolName, tint: tint, size: 30)
    }
}

private struct AccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [Account]

    private let editing: Account?

    @State private var name: String
    @State private var kind: AccountKind
    @State private var symbolName: String
    @State private var color: Color
    @State private var openingBalance: Decimal
    @State private var openingDate: Date
    @State private var closingDay: Int
    @State private var dueDay: Int

    init(editing: Account? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        let initialKind = editing?.kind ?? .bank
        _kind = State(initialValue: initialKind)
        _symbolName = State(initialValue: editing?.symbolName ?? initialKind.defaultSymbolName)
        _color = State(initialValue: editing.map { Color(hex: $0.colorHex) } ?? Color(hex: "#3B82F6"))
        // For credit cards, the stored balance is negative (debt). Show it as a
        // positive number in the editor so the user types what they intuitively owe.
        let rawBalance = editing?.openingBalance ?? 0
        let editableBalance = initialKind == .creditCard ? abs(rawBalance) : rawBalance
        _openingBalance = State(initialValue: editableBalance)
        _openingDate = State(initialValue: editing?.openingDate ?? .now)
        _closingDay = State(initialValue: editing?.closingDay ?? 0)
        _dueDay = State(initialValue: editing?.dueDay ?? 0)
    }

    private var isEditing: Bool { editing != nil }
    private var hasUsage: Bool { (editing?.transactions.count ?? 0) > 0 }

    private var namePlaceholder: String {
        switch kind {
        case .creditCard: return "Cartão Inter, Cartão Giovanna…"
        case .investment: return "CDB Inter, Tesouro Selic…"
        case .bank:       return "Banco Inter, Carteira…"
        }
    }

    private var balanceTitle: String {
        switch kind {
        case .creditCard: return "Fatura em aberto"
        case .investment: return "Saldo investido"
        case .bank:       return "Saldo inicial"
        }
    }

    private var balanceHint: String {
        switch kind {
        case .bank:
            return "Quanto tem nessa conta no dia em que você começou a usar o app."
        case .creditCard:
            return "Quanto já está devendo neste cartão. Deixe R$ 0,00 se não há fatura pendente."
        case .investment:
            return "Quanto já está aplicado neste investimento. Use R$ 0,00 se vai começar a aportar agora."
        }
    }

    private var sheetHeight: CGFloat {
        kind == .creditCard ? 560 : 480
    }

    private var billingHint: String {
        "Compras até o fechamento entram na fatura; o vencimento é o prazo para pagar."
    }

    var body: some View {
        VStack(spacing: 0) {
            CFAmountHeader(
                title: balanceTitle,
                amount: $openingBalance
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            Divider()
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 500, height: sheetHeight)
        .cfCompactSheetToolbar(
            title: isEditing ? "Editar conta" : "Nova conta",
            saveDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .onChange(of: kind) { oldValue, newValue in
            if !isEditing, symbolName == oldValue.defaultSymbolName {
                symbolName = newValue.defaultSymbolName
            }
            if newValue != .creditCard {
                closingDay = 0
                dueDay = 0
            }
        }
        .cfSheetBackground()
        .tint(CFTheme.accent)
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionGroup(title: "Identificação") {
                    CFInputField(label: "Nome", text: $name, placeholder: namePlaceholder)

                    panelDivider

                    panelRow("Tipo") {
                        CFSelectField(
                            selection: $kind,
                            options: AccountKind.selectOptions,
                            disabled: hasUsage
                        )
                    }

                    if hasUsage {
                        panelDivider
                        Text("Tipo bloqueado: há lançamentos nessa conta. Arquive e crie uma nova se precisar mudar.")
                            .font(CFTheme.caption())
                            .foregroundStyle(CFTheme.textSecondary)
                            .padding(.vertical, 4)
                    }
                }

                sectionGroup(title: "Ponto de partida", footnote: balanceHint) {
                    panelRow("Usando desde") {
                        DateField(date: $openingDate)
                    }
                }

                if kind == .creditCard {
                    sectionGroup(title: "Ciclo da fatura", footnote: billingHint) {
                        panelRow("Fechamento") {
                            HStack(spacing: 4) {
                                Text("dia")
                                    .font(CFTheme.caption())
                                    .foregroundStyle(CFTheme.textTertiary)
                                DayOfMonthField(day: $closingDay)
                            }
                        }

                        panelDivider

                        panelRow("Vencimento") {
                            HStack(spacing: 4) {
                                Text("dia")
                                    .font(CFTheme.caption())
                                    .foregroundStyle(CFTheme.textTertiary)
                                DayOfMonthField(day: $dueDay)
                            }
                        }
                    }
                }

                sectionGroup(title: "Aparência") {
                    panelRow("Ícone") {
                        IconPickerField(symbolName: $symbolName, tint: color)
                    }

                    panelDivider

                    panelRow("Cor") {
                        ColorPickerField(color: $color)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .scrollIndicators(.never)
    }

    private var panelDivider: some View {
        Divider().opacity(0.35)
    }

    private func sectionGroup<Content: View>(
        title: String,
        footnote: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CFTheme.surfaceElevated.opacity(0.38))
            )

            if let footnote {
                Text(footnote)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)
                    .padding(.horizontal, 2)
            }
        }
    }

    private func panelRow<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textSecondary)
            Spacer(minLength: 8)
            content()
        }
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if isEditing {
                CFPillButton(title: "Arquivar", icon: "archivebox", style: .destructive) {
                    archive()
                }
            }
            Spacer()
            CFPillButton(title: "Cancelar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            CFPillButton(title: "Salvar", style: .primary) {
                save()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .opacity(name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
            .allowsHitTesting(!name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalSymbol = symbolName.isEmpty ? kind.defaultSymbolName : symbolName
        let normalizedDate = Calendar.current.startOfDay(for: openingDate)
        // Cards store debt as negative balance internally.
        let storedBalance = kind == .creditCard ? -abs(openingBalance) : openingBalance

        if let editing {
            editing.name = trimmedName
            editing.symbolName = finalSymbol
            editing.colorHex = color.hexString
            editing.openingBalance = storedBalance
            editing.openingDate = normalizedDate
            editing.closingDay = kind == .creditCard ? closingDay : 0
            editing.dueDay = kind == .creditCard ? dueDay : 0
            if !hasUsage {
                editing.kind = kind
            }
        } else {
            let nextSort = (accounts.map(\.sortOrder).max() ?? -1) + 1
            let account = Account(
                name: trimmedName,
                kind: kind,
                colorHex: color.hexString,
                symbolName: finalSymbol,
                sortOrder: nextSort,
                openingBalance: storedBalance,
                openingDate: normalizedDate,
                closingDay: kind == .creditCard ? closingDay : 0,
                dueDay: kind == .creditCard ? dueDay : 0
            )
            modelContext.insert(account)
        }
    }

    private func archive() {
        editing?.isArchived = true
        dismiss()
    }
}

#if DEBUG
#Preview("Sheet — Nova conta banco") {
    AccountSheet()
        .previewSheet(width: 500, height: 490)
}

#Preview("Sheet — Novo cartão") {
    AccountSheet()
        .previewSheet(width: 500, height: 560)
}
#endif
