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
        ContentUnavailableView {
            Label("Nenhuma conta cadastrada", systemImage: "wallet.pass")
        } description: {
            Text("Conta é onde seu dinheiro mora: sua conta corrente, dinheiro vivo, cartão da namorada (dívida). Não confunda com categorias de gasto.")
        } actions: {
            Button {
                showingAdd = true
            } label: {
                Label("Criar primeira conta", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var accountList: some View {
        List {
            Section("Ativas") {
                ForEach(activeAccounts) { account in
                    accountRow(account)
                }
            }

            if !archivedAccounts.isEmpty {
                Section("Arquivadas") {
                    ForEach(archivedAccounts) { account in
                        HStack(spacing: 12) {
                            accountIcon(account, muted: true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(account.name)
                                    .foregroundStyle(.secondary)
                                Text(account.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
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
        .listStyle(.inset)
    }

    @ViewBuilder
    private func accountRow(_ account: Account) -> some View {
        let balance = account.currentBalance(considering: transactions)
        HStack(spacing: 12) {
            accountIcon(account, muted: false)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.name)
                    .foregroundStyle(.primary)
                Text(account.kind.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(balance.brl)
                    .font(.callout.monospacedDigit().weight(.medium))
                    .foregroundStyle(balanceColor(for: account, balance: balance))
                Text(account.kind == .externalDebt ? "Em aberto" : "Saldo atual")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                account.isArchived = true
            } label: {
                Label("Arquivar", systemImage: "archivebox")
            }
        }
    }

    private func balanceColor(for account: Account, balance: Decimal) -> Color {
        if account.kind == .externalDebt {
            return balance < 0 ? .pink : .secondary
        }
        return balance < 0 ? .red : .primary
    }

    private func accountIcon(_ account: Account, muted: Bool) -> some View {
        let tint = muted ? Color.secondary : Color(hex: account.colorHex)
        return ZStack {
            Circle()
                .fill(tint.opacity(0.16))
                .frame(width: 30, height: 30)
            Image(systemName: account.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
        }
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
        _kind = State(initialValue: editing?.kind ?? .checking)
        _symbolName = State(initialValue: editing?.symbolName ?? "creditcard.fill")
        _color = State(initialValue: editing.map { Color(hex: $0.colorHex) } ?? .blue)
        _openingBalance = State(initialValue: editing?.openingBalance ?? 0)
        _openingDate = State(initialValue: editing?.openingDate ?? .now)
    }

    private var isEditing: Bool { editing != nil }
    private var hasUsage: Bool { (editing?.transactions.count ?? 0) > 0 }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    LabeledContent("Nome") {
                        TextField("Banco Inter, Dinheiro…", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 220)
                    }
                    LabeledContent("Tipo") {
                        Picker("", selection: $kind) {
                            ForEach(AccountKind.allCases, id: \.self) { kind in
                                Text(kind.displayName).tag(kind)
                            }
                        }
                        .labelsHidden()
                        .disabled(hasUsage)
                    }
                    if hasUsage {
                        Text("Tipo bloqueado porque há lançamentos nessa conta. Arquive e crie uma nova se precisar mudar.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Saldo de partida") {
                    LabeledContent("Saldo") {
                        CurrencyField(amount: $openingBalance, placeholder: "R$ 0,00")
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 140)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("A partir de") {
                        DateField(date: $openingDate)
                    }
                }

                Section("Aparência") {
                    LabeledContent("Ícone") {
                        IconPickerField(symbolName: $symbolName, tint: color)
                    }
                    ColorPicker("Cor", selection: $color, supportsOpacity: false)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if isEditing {
                    Button(role: .destructive) {
                        archive()
                    } label: {
                        Label("Arquivar", systemImage: "archivebox")
                    }
                }
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 480, height: 520)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let finalSymbol = symbolName.isEmpty ? "creditcard.fill" : symbolName
        let normalizedDate = Calendar.current.startOfDay(for: openingDate)

        if let editing {
            editing.name = trimmedName
            editing.symbolName = finalSymbol
            editing.colorHex = color.hexString
            editing.openingBalance = openingBalance
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
                openingBalance: openingBalance,
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
