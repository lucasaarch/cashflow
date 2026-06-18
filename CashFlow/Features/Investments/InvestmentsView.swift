import SwiftUI
import SwiftData

struct FundTransferRow: Identifiable {
    let id: UUID
    let date: Date
    let amount: Decimal
    let title: String
    let subtitle: String
    let isPlanned: Bool
    let fundKind: AccountKind
}

struct InvestmentsView: View {
    @EnvironmentObject private var privacy: PrivacyMode

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @State private var showingTransfer = false
    @State private var transferFundID: UUID?
    @State private var transferDirection: FundTransferDirection = .deposit

    private var investmentAccounts: [Account] {
        accounts.filter { $0.kind == .investment }
    }

    private var goalAccounts: [Account] {
        accounts.filter { $0.kind == .goal }
    }

    private var bankAccounts: [Account] {
        accounts.filter { $0.kind == .bank }
    }

    private var fundAccounts: [Account] {
        investmentAccounts + goalAccounts
    }

    private var overview: FinancialOverview {
        FinancialOverview(accounts: accounts, transactions: transactions)
    }

    private var monthSummary: MonthSummary {
            MonthSummary(
            referenceDate: .now,
            transactions: transactions
        )
    }

    private var recentTransfers: [FundTransferRow] {
        FundTransferHistory.build(from: transactions, limit: 12)
    }

    private var hasFunds: Bool { !fundAccounts.isEmpty }
    private var canTransfer: Bool { !bankAccounts.isEmpty && hasFunds }

    var body: some View {
        Group {
            if !hasFunds {
                emptyState
            } else {
                content
            }
        }
        .navigationTitle("Investimentos")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openTransfer()
                } label: {
                    Label("Aportar", systemImage: "plus")
                }
                .disabled(!canTransfer)
                .help(canTransfer ? "Registrar aporte ou resgate" : "Cadastre uma conta bancária e um fundo")
            }
        }
        .sheet(isPresented: $showingTransfer) {
            FundTransferSheet(
                preselectedFundID: transferFundID,
                initialDirection: transferDirection
            )
        }
        .cfPageBackground()
    }

    private var emptyState: some View {
        CFEmptyState(
            symbol: "chart.line.uptrend.xyaxis",
            title: "Nenhum fundo cadastrado",
            message: "Crie contas do tipo investimento ou meta em Contas para registrar aportes e resgates aqui.",
            actionTitle: canTransfer ? "Registrar aporte" : nil
        ) {
            openTransfer()
        }
    }

    private var content: some View {
        CFScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                summaryHeader

                if !investmentAccounts.isEmpty {
                    fundSection(title: "Investimentos", accounts: investmentAccounts)
                }

                if !goalAccounts.isEmpty {
                    fundSection(title: "Metas (reservas)", accounts: goalAccounts)
                }

                if !recentTransfers.isEmpty {
                    transfersSection
                }
            }
            .padding(20)
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total alocado")
                .font(CFTheme.caption().weight(.medium))
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)

            CFAnimatedAmount(
                amount: overview.investmentBalance + overview.goalReservedBalance,
                font: CFTheme.heroAmount(),
                color: CFTheme.textPrimary
            )

            if let breakdown = summaryBreakdown {
                Text(breakdown)
                    .font(CFTheme.caption())
                    .foregroundStyle(CFTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    private var summaryBreakdown: String? {
        var parts: [String] = []
        if overview.investmentBalance > 0 {
            parts.append("Investido \(overview.investmentBalance.brl(masked: privacy.valuesHidden))")
        }
        if overview.goalReservedBalance > 0 {
            parts.append("Metas \(overview.goalReservedBalance.brl(masked: privacy.valuesHidden))")
        }
        if monthSummary.investedThisMonth != 0 {
            let sign = monthSummary.investedThisMonth >= 0 ? "+" : ""
            parts.append("\(sign)\(monthSummary.investedThisMonth.brl(masked: privacy.valuesHidden)) no mês")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private func fundSection(title: String, accounts: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(accounts) { account in
                let balance = account.currentBalance(considering: transactions)
                CFHoverRow {
                    HStack(spacing: 12) {
                        CFIconBadge(
                            symbolName: account.symbolName,
                            tint: Color(hex: account.colorHex),
                            size: 34
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(CFTheme.body().weight(.medium))
                                .foregroundStyle(CFTheme.textPrimary)
                            Text(account.kind.displayName)
                                .font(CFTheme.caption())
                                .foregroundStyle(CFTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        Text(balance.brl(masked: privacy.valuesHidden))
                            .font(CFTheme.kpiValue())
                            .foregroundStyle(CFTheme.textPrimary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    openTransfer(to: account, direction: .deposit)
                }
                .contextMenu {
                    Button {
                        openTransfer(to: account, direction: .deposit)
                    } label: {
                        Label("Aportar", systemImage: "arrow.down.circle")
                    }
                    Button {
                        openTransfer(to: account, direction: .withdraw)
                    } label: {
                        Label("Resgatar", systemImage: "arrow.up.circle")
                    }
                }
            }
        }
    }

    private var transfersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Movimentações recentes")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)

            ForEach(recentTransfers) { row in
                CFHoverRow {
                    HStack(spacing: 12) {
                        CFIconBadge(
                            symbolName: row.fundKind == .investment ? "chart.line.uptrend.xyaxis" : "flag.fill",
                            tint: CFTheme.accent,
                            size: 30
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(CFTheme.body())
                                .foregroundStyle(CFTheme.textPrimary)
                            Text(row.subtitle)
                                .font(CFTheme.caption())
                                .foregroundStyle(CFTheme.textSecondary)
                        }
                        Spacer(minLength: 0)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(row.amount.brl(masked: privacy.valuesHidden))
                                .font(CFTheme.kpiValue())
                                .foregroundStyle(CFTheme.textPrimary)
                            if row.isPlanned {
                                Text("Previsto")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(CFTheme.warning)
                            }
                        }
                    }
                }
            }
        }
    }

    private func openTransfer(
        to account: Account? = nil,
        direction: FundTransferDirection = .deposit
    ) {
        transferFundID = account?.id
        transferDirection = direction
        showingTransfer = true
    }
}

enum FundTransferHistory {
    static func build(from transactions: [Transaction], limit: Int) -> [FundTransferRow] {
        let fundTransfers = transactions.filter {
            $0.isTransfer && ($0.account?.kind == .investment || $0.account?.kind == .goal)
        }

        let grouped = Dictionary(grouping: fundTransfers) { $0.transferGroupID ?? $0.id }
        let now = Calendar.current.startOfDay(for: .now)

        let rows: [FundTransferRow] = grouped.compactMap { groupID, legs in
            guard let fundLeg = legs.first(where: {
                $0.account?.kind == .investment || $0.account?.kind == .goal
            }),
            let fundAccount = fundLeg.account,
            let bankLeg = legs.first(where: { $0.account?.kind == .bank })
            else { return nil }

            let isDeposit = fundLeg.kind == .income
            let title: String
            if isDeposit {
                title = fundAccount.kind == .investment ? "Aporte" : "Depósito em meta"
            } else {
                title = fundAccount.kind == .investment ? "Resgate" : "Retirada de meta"
            }

            let bankName = bankLeg.account?.name ?? "Banco"
            let date = legs.map(\.occurredOn).max() ?? fundLeg.occurredOn
            let subtitle = "\(bankName) · \(fundAccount.name) · \(date.formatted(date: .abbreviated, time: .omitted))"

            return FundTransferRow(
                id: groupID,
                date: date,
                amount: fundLeg.amount,
                title: title,
                subtitle: subtitle,
                isPlanned: date > now,
                fundKind: fundAccount.kind
            )
        }

        return rows
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }
}
