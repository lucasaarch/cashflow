import Foundation

struct FinancialAIContextInput {
    let referenceDate: Date
    let monthlyIncomeCents: Int
    let transactions: [Transaction]
    let accounts: [Account]
    let bills: [Bill]
    let receivables: [Receivable]
    let goals: [FinancialGoal]
    let recurringExpenses: [RecurringExpense]
    let recurringIncomes: [RecurringIncome]
    var calendar: Calendar = .current
    var now: Date = .now
    var previousMonthExpense: Decimal?
}

enum AIContextBuilder {
    static let maxCharacters = 16_000

    // MARK: - Public entry points

    static func financialSnapshot(
        transactions: [Transaction],
        accounts: [Account],
        bills: [Bill] = [],
        receivables: [Receivable] = [],
        goals: [FinancialGoal] = [],
        recurringExpenses: [RecurringExpense] = [],
        recurringIncomes: [RecurringIncome] = [],
        monthlyIncomeCents: Int,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let input = FinancialAIContextInput(
            referenceDate: referenceDate,
            monthlyIncomeCents: monthlyIncomeCents,
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            receivables: receivables,
            goals: goals,
            recurringExpenses: recurringExpenses,
            recurringIncomes: recurringIncomes,
            calendar: calendar,
            now: referenceDate
        )
        return buildFullSnapshot(input, includeRecentHistory: true)
    }

    static func dashboardOverviewSnapshot(
        summary: MonthSummary,
        overview: FinancialOverview,
        accounts: [Account],
        bills: [Bill],
        receivables: [Receivable],
        goals: [FinancialGoal],
        transactions: [Transaction],
        recurringExpenses: [RecurringExpense],
        recurringIncomes: [RecurringIncome],
        previousMonthExpense: Decimal,
        monthlyIncomeCents: Int,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> String {
        let input = FinancialAIContextInput(
            referenceDate: summary.referenceDate,
            monthlyIncomeCents: monthlyIncomeCents,
            transactions: transactions,
            accounts: accounts,
            bills: bills,
            receivables: receivables,
            goals: goals,
            recurringExpenses: recurringExpenses,
            recurringIncomes: recurringIncomes,
            calendar: calendar,
            now: now,
            previousMonthExpense: previousMonthExpense
        )
        return buildFullSnapshot(input, includeRecentHistory: false)
    }

    // MARK: - Builder

    private static func buildFullSnapshot(
        _ input: FinancialAIContextInput,
        includeRecentHistory: Bool
    ) -> String {
        let summary = MonthSummary(
            referenceDate: input.referenceDate,
            monthlyIncomeFallback: Decimal(input.monthlyIncomeCents) / 100,
            transactions: input.transactions,
            pendingReceivables: input.receivables,
            calendar: input.calendar,
            now: input.now
        )
        let overview = FinancialOverview(
            accounts: input.accounts,
            transactions: input.transactions,
            bills: input.bills,
            asOf: input.referenceDate,
            now: input.now
        )

        var sections: [String] = []
        sections.append(headerSection(input, summary: summary))
        sections.append(patrimonySection(overview))
        sections.append(accountBalancesSection(input))
        sections.append(monthFlowSection(summary, previousMonthExpense: input.previousMonthExpense))
        sections.append(categoriesSection(summary))
        sections.append(accountExpensesSection(summary))
        sections.append(pendingBillsSection(input))
        sections.append(pendingReceivablesSection(input))
        sections.append(recurringExpensesSection(input))
        sections.append(recurringIncomesSection(input))
        sections.append(goalsSection(input, summary: summary))
        sections.append(investmentsSection(summary, overview: overview))
        sections.append(transfersSection(summary, calendar: input.calendar, now: input.now))
        sections.append(plannedTransactionsSection(summary, calendar: input.calendar, now: input.now))
        sections.append(realizedTransactionsSection(summary, calendar: input.calendar, now: input.now))

        if includeRecentHistory {
            sections.append(recentHistorySection(input))
        }

        return fitSections(sections)
    }

    private static func fitSections(_ sections: [String]) -> String {
        var included = sections.filter { !$0.isEmpty }
        var body = included.joined(separator: "\n\n")

        guard body.count > maxCharacters else { return body }

        // Drop lowest-priority tail sections until we fit.
        let trimOrder = [
            "LANÇAMENTOS RECENTES",
            "LANÇAMENTOS REALIZADOS DO MÊS",
            "LANÇAMENTOS PREVISTOS",
            "TRANSFERÊNCIAS DO MÊS"
        ]

        for marker in trimOrder {
            if body.count <= maxCharacters { break }
            if let index = included.lastIndex(where: { $0.hasPrefix("=== \(marker)") }) {
                included.remove(at: index)
                body = included.joined(separator: "\n\n")
            }
        }

        if body.count > maxCharacters, let last = included.last, last.hasPrefix("=== LANÇAMENTOS") {
            included[included.count - 1] = truncateTransactionSection(last, maxLength: max(800, maxCharacters - (body.count - last.count)))
            body = included.joined(separator: "\n\n")
        }

        if body.count > maxCharacters {
            body = String(body.prefix(maxCharacters - 20)) + "\n…(contexto truncado)"
        }

        return body
    }

    private static func truncateTransactionSection(_ section: String, maxLength: Int) -> String {
        let lines = section.components(separatedBy: "\n")
        guard lines.count > 2 else { return section }
        var result = [lines[0], lines[1]]
        for line in lines.dropFirst(2) {
            let candidate = (result + [line]).joined(separator: "\n")
            if candidate.count > maxLength { break }
            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    // MARK: - Sections

    private static func headerSection(_ input: FinancialAIContextInput, summary: MonthSummary) -> String {
        let month = input.referenceDate.formatted(.dateTime.month(.wide).year())
        var lines = ["=== CONTEXTO FINANCEIRO — \(month) ===", ""]
        lines.append("Data de referência: \(input.now.formatted(date: .abbreviated, time: .omitted))")
        if summary.usesFallbackIncome, input.monthlyIncomeCents > 0 {
            lines.append("Renda esperada (fallback manual): \((Decimal(input.monthlyIncomeCents) / 100).brl)")
        }
        return lines.joined(separator: "\n")
    }

    private static func patrimonySection(_ overview: FinancialOverview) -> String {
        var lines = ["=== PATRIMÔNIO ===", ""]
        lines.append("- Patrimônio líquido: \(overview.netWorth.brl)")
        lines.append("- Disponível: \(overview.liquidBalance.brl)")
        if overview.debtBalance > 0 {
            lines.append("- Cartões (dívida): \(overview.debtBalance.brl)")
        }
        if overview.investmentBalance > 0 {
            lines.append("- Investido: \(overview.investmentBalance.brl)")
        }
        if overview.goalReservedBalance > 0 {
            lines.append("- Reservado em metas: \(overview.goalReservedBalance.brl)")
        }
        if overview.pendingBillsTotal > 0 {
            let overdue = overview.overdueBillsCount > 0
                ? " (\(overview.overdueBillsCount) vencida\(overview.overdueBillsCount == 1 ? "" : "s"))"
                : ""
            lines.append("- Contas a pagar pendentes (total): \(overview.pendingBillsTotal.brl)\(overdue)")
        }
        return lines.joined(separator: "\n")
    }

    private static func accountBalancesSection(_ input: FinancialAIContextInput) -> String {
        var lines = ["=== SALDOS POR CONTA ===", ""]
        for account in input.accounts where !account.isArchived {
            let balance = account.currentBalance(considering: input.transactions, asOf: input.referenceDate)
            lines.append("- \(account.name) (\(account.kind.displayName)): \(balance.brl)")
        }
        return lines.joined(separator: "\n")
    }

    private static func monthFlowSection(_ summary: MonthSummary, previousMonthExpense: Decimal?) -> String {
        var lines = ["=== FLUXO DO MÊS ===", ""]
        lines.append("- Realizado entrou: \(summary.totalIncome.brl) (dinheiro que JÁ caiu na conta)")
        lines.append("- Realizado saiu: \(summary.totalExpense.brl) (despesas JÁ pagas)")
        lines.append("- Saldo realizado do mês: \(summary.balance.brl) (entrou − saiu, sem incluir expectativa)")
        if summary.plannedIncome > 0 {
            lines.append("- Previsto entrar (lançamentos futuros no mês): \(summary.plannedIncome.brl)")
        }
        if summary.pendingReceivableIncome > 0 {
            lines.append("- A receber no mês (receivables pendentes): \(summary.pendingReceivableIncome.brl)")
        }
        if summary.plannedExpense > 0 {
            lines.append("- Previsto sair (lançamentos futuros no mês): \(summary.plannedExpense.brl)")
        }
        lines.append("- Renda esperada para o mês: \(summary.expectedIncome.brl) (\(summary.usesFallbackIncome ? "fallback manual" : "rendas fixas + receivables + previstos"))")
        lines.append("- Saldo projetado fim do mês: \(summary.projectedBalance.brl)")
        if summary.expectedIncome > 0 {
            lines.append("- Ritmo: \(summary.paceState.label) (\(Int(summary.spentRatio * 100))% da renda esperada gasta, \(Int(summary.dayProgress * 100))% do mês transcorrido)")
            lines.append("- Dias restantes: \(summary.daysRemaining) | Saldo diário restante: \(summary.dailyBudgetRemaining.brl)")
        }
        if let previousMonthExpense {
            lines.append("- Despesas mês anterior: \(previousMonthExpense.brl)")
        }
        return lines.joined(separator: "\n")
    }

    private static func categoriesSection(_ summary: MonthSummary) -> String {
        let top = summary.expensesByCategory.prefix(8)
        guard !top.isEmpty else { return "" }
        var lines = ["=== MAIORES CATEGORIAS (despesas realizadas) ===", ""]
        for item in top {
            let pct = summary.totalExpense > 0
                ? Int(NSDecimalNumber(decimal: item.total / summary.totalExpense * 100).doubleValue)
                : 0
            lines.append("- \(item.category.name): \(item.total.brl) (\(pct)%, \(item.count) lançamento\(item.count == 1 ? "" : "s"))")
        }
        return lines.joined(separator: "\n")
    }

    private static func accountExpensesSection(_ summary: MonthSummary) -> String {
        let items = summary.expensesByAccount
        guard !items.isEmpty else { return "" }
        var lines = ["=== GASTOS POR CONTA (realizados) ===", ""]
        for item in items {
            lines.append("- \(item.account.name): \(item.total.brl) (\(item.count) lançamento\(item.count == 1 ? "" : "s"))")
        }
        return lines.joined(separator: "\n")
    }

    private static func pendingBillsSection(_ input: FinancialAIContextInput) -> String {
        let pending = input.bills
            .filter { $0.isPending }
            .sorted { $0.dueDate < $1.dueDate }
        guard !pending.isEmpty else { return "" }
        var lines = ["=== CONTAS A PAGAR (todas pendentes) ===", ""]
        for bill in pending {
            lines.append(billLine(bill, now: input.now))
        }
        return lines.joined(separator: "\n")
    }

    private static func pendingReceivablesSection(_ input: FinancialAIContextInput) -> String {
        let pending = input.receivables
            .filter { $0.isPending }
            .sorted { $0.expectedDate < $1.expectedDate }
        guard !pending.isEmpty else { return "" }
        var lines = ["=== CONTAS A RECEBER (todas pendentes) ===", ""]
        for receivable in pending {
            lines.append(receivableLine(receivable, now: input.now))
        }
        return lines.joined(separator: "\n")
    }

    private static func recurringExpensesSection(_ input: FinancialAIContextInput) -> String {
        guard !input.recurringExpenses.isEmpty else { return "" }
        var lines = ["=== DESPESAS FIXAS (regras) ===", ""]
        for rule in input.recurringExpenses.sorted(by: { $0.name < $1.name }) {
            let status = rule.isPaused ? "pausada" : "ativa"
            let flow = rule.requiresConfirmation ? "gera conta a pagar (confirmação manual)" : "gera lançamento automático"
            var line = "- \(rule.name): \(rule.amount.brl)/mês | todo dia \(rule.dayOfMonth) | \(status) | \(flow)"
            if let account = rule.account { line += " | conta: \(account.name)" }
            if let category = rule.category { line += " | categoria: \(category.name)" }
            if let end = rule.endDate {
                line += " | até \(end.formatted(date: .abbreviated, time: .omitted))"
            }
            if !rule.note.isEmpty { line += " | nota: \(rule.note)" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private static func recurringIncomesSection(_ input: FinancialAIContextInput) -> String {
        guard !input.recurringIncomes.isEmpty else { return "" }
        var lines = ["=== RENDAS FIXAS (regras) ===", ""]
        for rule in input.recurringIncomes.sorted(by: { $0.name < $1.name }) {
            let status = rule.isPaused ? "pausada" : "ativa"
            let flow = rule.requiresConfirmation ? "gera conta a receber (confirmação manual)" : "gera lançamento automático"
            var line = "- \(rule.name): \(rule.amount.brl)/mês | todo dia \(rule.dayOfMonth) | \(status) | \(flow)"
            if let account = rule.account { line += " | conta: \(account.name)" }
            if let category = rule.category { line += " | categoria: \(category.name)" }
            if let end = rule.endDate {
                line += " | até \(end.formatted(date: .abbreviated, time: .omitted))"
            }
            if !rule.note.isEmpty { line += " | nota: \(rule.note)" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private static func goalsSection(_ input: FinancialAIContextInput, summary: MonthSummary) -> String {
        let active = input.goals.filter { !$0.isCompleted }
        guard !active.isEmpty else { return "" }
        var lines = ["=== METAS ATIVAS ===", ""]
        for goal in active {
            let snapshot = GoalProgressCalculator.snapshot(
                for: goal,
                transactions: input.transactions,
                asOf: summary.referenceDate,
                calendar: input.calendar
            )
            var line = "- \(goal.name): \(snapshot.currentAmount.brl) de \(snapshot.targetAmount.brl) (\(Int(snapshot.progress * 100))%)"
            if let deadline = goal.deadline {
                line += " | prazo: \(deadline.formatted(date: .abbreviated, time: .omitted))"
            }
            if !goal.notes.isEmpty { line += " | nota: \(goal.notes)" }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }

    private static func investmentsSection(_ summary: MonthSummary, overview: FinancialOverview) -> String {
        guard summary.investedThisMonth != 0 || overview.investmentBalance > 0 else { return "" }
        var lines = ["=== INVESTIMENTOS ===", ""]
        if summary.investedThisMonth != 0 {
            lines.append("- Aportes líquidos no mês (transferências): \(summary.investedThisMonth.brl)")
        }
        if overview.investmentBalance > 0 {
            lines.append("- Total investido: \(overview.investmentBalance.brl)")
        }
        return lines.joined(separator: "\n")
    }

    private static func transfersSection(_ summary: MonthSummary, calendar: Calendar, now: Date) -> String {
        let transfers = summary.monthlyTransactions.filter(\.isTransfer)
        guard !transfers.isEmpty else { return "" }
        var lines = ["=== TRANSFERÊNCIAS DO MÊS ===", ""]
        let grouped = Dictionary(grouping: transfers) { $0.transferGroupID ?? $0.id }
        for (_, legs) in grouped.sorted(by: { ($0.value.first?.occurredOn ?? .distantPast) > ($1.value.first?.occurredOn ?? .distantPast) }) {
            for leg in legs.sorted(by: { $0.occurredOn < $1.occurredOn }) {
                lines.append(transactionLine(leg, calendar: calendar, now: now))
            }
            if legs.count > 1 { lines.append("") }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func plannedTransactionsSection(_ summary: MonthSummary, calendar: Calendar, now: Date) -> String {
        let planned = summary.plannedMonthlyTransactions.sorted { $0.occurredOn < $1.occurredOn }
        guard !planned.isEmpty else { return "" }
        var lines = ["=== LANÇAMENTOS PREVISTOS (mês, data futura) ===", ""]
        for txn in planned {
            lines.append(transactionLine(txn, calendar: calendar, now: now))
        }
        return lines.joined(separator: "\n")
    }

    private static func realizedTransactionsSection(_ summary: MonthSummary, calendar: Calendar, now: Date) -> String {
        let realized = summary.realizedMonthlyTransactions
            .filter { !$0.isTransfer }
            .sorted { $0.occurredOn > $1.occurredOn }
        guard !realized.isEmpty else { return "" }
        var lines = ["=== LANÇAMENTOS REALIZADOS DO MÊS ===", ""]
        for txn in realized {
            lines.append(transactionLine(txn, calendar: calendar, now: now))
        }
        return lines.joined(separator: "\n")
    }

    private static func recentHistorySection(_ input: FinancialAIContextInput) -> String {
        let cutoff = input.calendar.date(byAdding: .day, value: -90, to: input.now) ?? input.now
        let recent = input.transactions
            .filter { $0.occurredOn >= cutoff }
            .sorted { $0.occurredOn > $1.occurredOn }
        guard !recent.isEmpty else { return "" }
        var lines = ["=== LANÇAMENTOS RECENTES (últimos 90 dias) ===", ""]
        for txn in recent {
            lines.append(transactionLine(txn, calendar: input.calendar, now: input.now))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Line formatters

    private static func transactionLine(_ transaction: Transaction, calendar: Calendar, now: Date) -> String {
        let date = transaction.occurredOn.formatted(date: .abbreviated, time: .omitted)
        let status = transaction.occurredOn > now ? "PREVISTO" : "REALIZADO"
        let kind = transaction.isTransfer ? transferLabel(transaction) : transaction.kind.displayName.uppercased()
        let category = transaction.category?.name ?? (transaction.isTransfer ? "—" : "Sem categoria")
        let account = transaction.account?.name ?? "Sem conta"

        var parts = [
            date,
            status,
            kind,
            transaction.amount.brl,
            "categoria: \(category)",
            "conta: \(account)"
        ]

        if transaction.isTransfer, let groupID = transaction.transferGroupID {
            parts.append("grupo: \(groupID.uuidString.prefix(8))")
        }
        if transaction.isInstallment, let plan = transaction.installmentPlan {
            parts.append("parcela \(transaction.installmentIndex)/\(plan.installmentCount)")
        }
        if let source = transaction.recurringSource {
            parts.append("despesa fixa: \(source.name)")
        }
        if let source = transaction.recurringIncomeSource {
            parts.append("renda fixa: \(source.name)")
        }
        if let billing = transaction.billingCycleCaption(calendar: calendar) {
            parts.append(billing)
        }
        if !transaction.note.isEmpty {
            parts.append("nota: \(transaction.note)")
        }

        return "- " + parts.joined(separator: " | ")
    }

    private static func transferLabel(_ transaction: Transaction) -> String {
        switch (transaction.account?.kind, transaction.kind) {
        case (.investment, .income), (.bank, .expense):
            return "TRANSFERÊNCIA/APORTE"
        case (.investment, .expense), (.bank, .income):
            return "TRANSFERÊNCIA/RESGATE"
        default:
            return "TRANSFERÊNCIA"
        }
    }

    private static func billLine(_ bill: Bill, now: Date) -> String {
        let status: String
        if bill.isOverdue(now: now) {
            status = "VENCIDA"
        } else {
            status = "a vencer"
        }
        var parts = [
            bill.name,
            bill.amount.brl,
            "venc: \(bill.dueDate.formatted(date: .abbreviated, time: .omitted))",
            status
        ]
        if bill.isCardStatement, let card = bill.cardStatementSource {
            parts.append("fatura cartão: \(card.name)")
        }
        if let category = bill.category { parts.append("categoria: \(category.name)") }
        if let account = bill.account { parts.append("conta: \(account.name)") }
        if let source = bill.recurringSource { parts.append("despesa fixa: \(source.name)") }
        if !bill.note.isEmpty { parts.append("nota: \(bill.note)") }
        return "- " + parts.joined(separator: " | ")
    }

    private static func receivableLine(_ receivable: Receivable, now: Date) -> String {
        let status = receivable.isLate(now: now) ? "ATRASADA" : "a receber"
        var parts = [
            receivable.name,
            receivable.amount.brl,
            "previsto: \(receivable.expectedDate.formatted(date: .abbreviated, time: .omitted))",
            status
        ]
        if let category = receivable.category { parts.append("categoria: \(category.name)") }
        if let account = receivable.account { parts.append("conta: \(account.name)") }
        if let source = receivable.recurringIncomeSource { parts.append("renda fixa: \(source.name)") }
        if !receivable.note.isEmpty { parts.append("nota: \(receivable.note)") }
        return "- " + parts.joined(separator: " | ")
    }
}
