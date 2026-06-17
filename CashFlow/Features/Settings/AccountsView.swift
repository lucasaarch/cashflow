import SwiftUI
import SwiftData

struct AccountsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Account.sortOrder)]) private var accounts: [Account]
    @Query private var transactions: [Transaction]

    @State private var showingAdd = false
    @State private var editingAccount: Account?

    var activeAccounts: [Account] {
        accounts.filter { !$0.isArchived }
    }

    var archivedAccounts: [Account] {
        accounts.filter { $0.isArchived }
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
                if !activeAccounts.isEmpty {
                    activeSection
                }

                if !archivedAccounts.isEmpty {
                    archivedSection
                }
            }
            .padding(20)
        }
        .cfPageBackground()
    }

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ativas")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(activeAccounts) { account in
                let balance = account.currentBalance(considering: transactions)
                CFHoverRow {
                    accountRowContent(account, balance: balance)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    editingAccount = account
                }
                .contextMenu {
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
                Text(account.kind.displayName)
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

    private func balanceColor(for account: Account, balance: Decimal) -> Color {
        switch account.kind {
        case .bank:
            return balance < 0 ? CFTheme.danger : CFTheme.textPrimary
        case .creditCard:
            return CFTheme.debt
        }
    }

    private func displayedBalance(for account: Account, balance: Decimal) -> Decimal {
        switch account.kind {
        case .bank:
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

    init(editing: Account? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        let initialKind = editing?.kind ?? .bank
        _kind = State(initialValue: initialKind)
        _symbolName = State(initialValue: editing?.symbolName ?? initialKind.defaultSymbolName)
        _color = State(initialValue: editing.map { Color(hex: $0.colorHex) } ?? .blue)
        // For credit cards, the stored balance is negative (debt). Show it as a
        // positive number in the editor so the user types what they intuitively owe.
        let rawBalance = editing?.openingBalance ?? 0
        let editableBalance = initialKind == .creditCard ? abs(rawBalance) : rawBalance
        _openingBalance = State(initialValue: editableBalance)
        _openingDate = State(initialValue: editing?.openingDate ?? .now)
    }

    private var isEditing: Bool { editing != nil }
    private var hasUsage: Bool { (editing?.transactions.count ?? 0) > 0 }

    private var namePlaceholder: String {
        kind == .creditCard ? "Cartão Inter, Cartão Giovanna…" : "Banco Inter, Carteira…"
    }

    private var balanceSectionTitle: String {
        kind == .creditCard ? "Fatura inicial" : "Saldo de partida"
    }

    private var balanceFieldLabel: String {
        kind == .creditCard ? "Já devo" : "Saldo"
    }

    private var balanceHint: String {
        switch kind {
        case .bank:
            return "Quanto tem nessa conta no dia que você começou a usar o app."
        case .creditCard:
            return "Quanto já está em aberto/devendo nesse cartão. Deixe R$ 0,00 se não tem fatura pendente."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 500, height: 620)
        .onChange(of: kind) { oldValue, newValue in
            // If user hasn't picked a custom icon, swap the default to match the new kind.
            if !isEditing, symbolName == oldValue.defaultSymbolName {
                symbolName = newValue.defaultSymbolName
            }
        }
        .presentationBackground(.ultraThinMaterial)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            CFIconBadge(
                symbolName: symbolName.isEmpty ? kind.defaultSymbolName : symbolName,
                tint: color,
                size: 64
            )
            .shadow(color: color.opacity(0.18), radius: 12, x: 0, y: 6)

            VStack(spacing: 3) {
                Text(name.isEmpty ? (isEditing ? "Sem nome" : "Nova conta") : name)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(name.isEmpty ? CFTheme.textSecondary : CFTheme.textPrimary)
                    .lineLimit(1)
                Text(heroSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(CFTheme.textSecondary)
                    .monospacedDigit()
            }
        }
        .padding(.top, 26)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
    }

    private var heroSubtitle: String {
        let kindLabel = kind.displayName
        if openingBalance == 0 {
            return kind == .creditCard ? "\(kindLabel) · fatura zerada" : "\(kindLabel) · sem saldo"
        }
        let amount = openingBalance.brl
        return kind == .creditCard ? "\(kindLabel) · devo \(amount)" : "\(kindLabel) · \(amount)"
    }

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                section(title: "Identificação") {
                    CFInputField(label: "Nome", text: $name, placeholder: namePlaceholder)

                    labeledRow("Tipo") {
                        Picker("Tipo", selection: $kind) {
                            ForEach(AccountKind.allCases, id: \.self) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .disabled(hasUsage)
                    }
                }

                if hasUsage {
                    Text("Tipo bloqueado: há lançamentos nessa conta. Arquive e crie uma nova se precisar mudar.")
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                }

                section(title: balanceSectionTitle) {
                    labeledRow(balanceFieldLabel) {
                        CurrencyField(amount: $openingBalance, placeholder: "R$ 0,00")
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 180)
                    }
                    labeledRow("Desde") {
                        DateField(date: $openingDate)
                    }
                }

                Text(balanceHint)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textSecondary)

                section(title: "Aparência") {
                    labeledRow("Ícone") {
                        IconPickerField(symbolName: $symbolName, tint: color)
                    }
                    ColorPicker("Cor", selection: $color, supportsOpacity: false)
                        .foregroundStyle(CFTheme.textPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .scrollIndicators(.never)
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
            if isEditing {
                CFPillButton(title: "Arquivar", icon: "archivebox", style: .destructive) {
                    archive()
                }
            }
            Spacer()
            CFPillButton(title: "Cancelar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            CFPillButton(title: "Salvar", icon: "checkmark", style: .primary) {
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
                openingDate: normalizedDate
            )
            modelContext.insert(account)
        }
    }

    private func archive() {
        editing?.isArchived = true
        dismiss()
    }
}
