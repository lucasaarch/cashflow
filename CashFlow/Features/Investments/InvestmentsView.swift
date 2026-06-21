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
    #if os(macOS)
    @EnvironmentObject private var spotlightNavigation: SpotlightNavigationState
    #endif

    @Query(filter: #Predicate<Account> { !$0.isArchived },
           sort: [SortDescriptor(\Account.sortOrder)])
    private var accounts: [Account]

    @Query(sort: [SortDescriptor(\Transaction.occurredOn, order: .reverse)])
    private var transactions: [Transaction]

    @State private var showingTransfer = false
    @State private var transferFundID: UUID?
    @State private var transferDirection: FundTransferDirection = .deposit
    @State private var fundActionAccount: Account?
    #if os(macOS)
    @State private var highlightedFundID: UUID?
    @State private var spotlightFocusTask: Task<Void, Never>?
    #endif
    private var allFundAccounts: [Account] {
        accounts.filter { $0.kind == .investment || $0.kind == .goal }
    }

    private var investmentAccounts: [Account] {
        allFundAccounts.filter { $0.kind == .investment }
    }

    private var goalAccounts: [Account] {
        allFundAccounts.filter { $0.kind == .goal }
    }

    private var bankAccounts: [Account] {
        accounts.filter { $0.kind == .bank }
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

    private var hasFunds: Bool { !allFundAccounts.isEmpty }
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
        .detailToolbarAdd(
            help: canTransfer ? "Registrar aporte ou resgate" : "Cadastre uma conta bancária e um fundo",
            disabled: !canTransfer
        ) {
            openTransfer()
        }
        .sheet(isPresented: $showingTransfer) {
            FundTransferSheet(
                preselectedFundID: transferFundID,
                initialDirection: transferDirection
            )
        }
        .confirmationDialog(
            "Movimentação",
            isPresented: Binding(
                get: { fundActionAccount != nil },
                set: { if !$0 { fundActionAccount = nil } }
            ),
            presenting: fundActionAccount
        ) { account in
            Button("Aportar") {
                openTransfer(to: account, direction: .deposit)
            }
            Button("Resgatar") {
                openTransfer(to: account, direction: .withdraw)
            }
            Button("Cancelar", role: .cancel) {
                fundActionAccount = nil
            }
        } message: { account in
            Text(account.name)
        }
        .cfGlassDetailChrome()
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
        ScrollViewReader { proxy in
            CFGlassPage {
                CFGlassPageStack {
                    summaryHeader(staggerIndex: 0)

                    if !investmentAccounts.isEmpty {
                        fundSection(
                            title: "Investimentos",
                            accounts: investmentAccounts,
                            staggerIndex: 1
                        )
                    }

                    if !goalAccounts.isEmpty {
                        fundSection(
                            title: "Metas (reservas)",
                            accounts: goalAccounts,
                            staggerIndex: investmentAccounts.isEmpty ? 1 : 2
                        )
                    }

                    if !recentTransfers.isEmpty {
                        transfersSection(
                            staggerIndex: sectionCountBeforeTransfers
                        )
                    }
                }
            }
            #if os(macOS)
            .spotlightScrollTarget(
                activeTarget: spotlightNavigation.activeTarget,
                extractID: { target in
                    guard let id = target.entityID(matching: .account),
                          allFundAccounts.contains(where: { $0.id == id }) else { return nil }
                    return id
                },
                openDetailOnFocus: spotlightNavigation.openDetailOnFocus,
                highlightedID: $highlightedFundID,
                focusTask: $spotlightFocusTask,
                proxy: proxy,
                onReveal: { id in
                    if let account = allFundAccounts.first(where: { $0.id == id }) {
                        openTransfer(to: account, direction: .deposit)
                    }
                },
                clearNavigation: spotlightNavigation.clearTarget
            )
            #endif
        }
    }

    private var sectionCountBeforeTransfers: Int {
        var count = 1
        if !investmentAccounts.isEmpty { count += 1 }
        if !goalAccounts.isEmpty { count += 1 }
        return count
    }

    private func summaryHeader(staggerIndex: Int) -> some View {
        CFGlassSummaryPanel(title: "Total alocado", staggerIndex: staggerIndex, tint: CFTheme.accent) {
            CFAnimatedAmount(
                amount: overview.investmentBalance + overview.goalReservedBalance,
                font: CFTheme.heroAmount(),
                color: CFTheme.textPrimary
            )

            if let breakdown = summaryBreakdown {
                Text(breakdown)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var summaryBreakdown: String? {
        var parts: [String] = []
        if overview.investmentBalance > 0 {
            parts.append("Investido \(overview.investmentBalance.brl)")
        }
        if overview.goalReservedBalance > 0 {
            parts.append("Metas \(overview.goalReservedBalance.brl)")
        }
        if monthSummary.investedThisMonth != 0 {
            let sign = monthSummary.investedThisMonth >= 0 ? "+" : ""
            parts.append("\(sign)\(monthSummary.investedThisMonth.brl) no mês")
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private func fundSection(title: String, accounts: [Account], staggerIndex: Int) -> some View {
        CFGlassSection(
            title: title,
            count: accounts.count,
            countTint: CFTheme.accent,
            staggerIndex: staggerIndex
        ) {
            CFGlassEnumeratedPanel(items: accounts) { account, _ in
                let balance = account.currentBalance(considering: transactions)
                CFGlassRowButton {
                    fundActionAccount = account
                } label: {
                    CFGlassAmountRow(
                        systemName: account.symbolName,
                        tint: Color(hex: account.colorHex),
                        title: account.name,
                        subtitle: account.kind.displayName,
                        amount: balance.brl
                    )
                }
                .id(account.id)
                #if os(macOS)
                .spotlightFocused(highlightedFundID == account.id)
                #endif
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

    private func transfersSection(staggerIndex: Int) -> some View {
        CFGlassSection(
            title: "Movimentações recentes",
            count: recentTransfers.count,
            countTint: CFTheme.accent,
            staggerIndex: staggerIndex
        ) {
            CFGlassPanel {
                VStack(spacing: 0) {
                    ForEach(Array(recentTransfers.enumerated()), id: \.element.id) { index, row in
                        CFGlassAmountRow(
                            systemName: row.fundKind == .investment ? "chart.line.uptrend.xyaxis" : "flag.fill",
                            tint: CFTheme.accent,
                            title: row.title,
                            subtitle: row.subtitle,
                            amount: row.amount.brl,
                            statusBadge: row.isPlanned ? "Previsto" : nil,
                            statusBadgeTint: CFTheme.warning
                        )
                        .padding(.horizontal, CFGlassMetrics.rowHorizontalPadding)
                        .padding(.vertical, CFGlassMetrics.rowVerticalPadding)

                        if index < recentTransfers.count - 1 {
                            CFGlassPanelDivider()
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

