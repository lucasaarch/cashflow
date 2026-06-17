import Foundation

enum AIContextBuilder {
    static let maxCharacters = 12_000

    static func financialSnapshot(
        transactions: [Transaction],
        accounts: [Account],
        goals: [FinancialGoal] = [],
        monthlyIncomeCents: Int,
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let budget = Decimal(monthlyIncomeCents) / 100
        let cutoff = calendar.date(byAdding: .day, value: -90, to: referenceDate) ?? referenceDate
        let recent = transactions
            .filter { $0.occurredOn >= cutoff }
            .sorted { $0.occurredOn > $1.occurredOn }

        let overview = FinancialOverview(
            accounts: accounts,
            transactions: transactions,
            asOf: referenceDate,
            now: referenceDate
        )

        var lines: [String] = []
        lines.append("Mês de referência: \(referenceDate.formatted(.dateTime.month(.wide).year()))")
        lines.append("Orçamento mensal: \(budget.brl)")
        lines.append("Patrimônio líquido: \(overview.netWorth.brl) (disponível \(overview.liquidBalance.brl), cartões \(overview.debtBalance.brl), investido \(overview.investmentBalance.brl))")
        lines.append("Saldos por conta:")
        for account in accounts where !account.isArchived {
            let balance = account.currentBalance(considering: transactions, asOf: referenceDate)
            lines.append("- \(account.name): \(balance.brl)")
        }

        let activeGoals = goals.filter { !$0.isCompleted }
        if !activeGoals.isEmpty {
            lines.append("Metas ativas:")
            for goal in activeGoals {
                let snapshot = GoalProgressCalculator.snapshot(
                    for: goal,
                    transactions: transactions,
                    asOf: referenceDate,
                    calendar: calendar
                )
                lines.append("- \(goal.name): \(snapshot.currentAmount.brl) de \(snapshot.targetAmount.brl) (\(Int(snapshot.progress * 100))%)")
            }
        }

        lines.append("Lançamentos (últimos 90 dias):")

        var transactionLines = recent.map { transactionLine($0) }
        var body = lines.joined(separator: "\n") + "\n"

        while !transactionLines.isEmpty {
            let candidate = body + transactionLines.joined(separator: "\n")
            if candidate.count <= maxCharacters { break }
            transactionLines.removeLast()
        }

        if transactionLines.isEmpty, let last = recent.last {
            transactionLines = [transactionLine(last)]
        }

        body += transactionLines.joined(separator: "\n")
        return body
    }

    private static func transactionLine(_ transaction: Transaction) -> String {
        let category = transaction.category?.name ?? "Sem categoria"
        let account = transaction.account?.name ?? "Sem conta"
        let date = transaction.occurredOn.formatted(date: .abbreviated, time: .omitted)
        let note = transaction.note.isEmpty ? "" : " | nota: \(transaction.note)"
        return "- \(date) | \(transaction.kind.rawValue) | \(transaction.amount.brl) | \(category) | \(account)\(note)"
    }

    /// Full dashboard context for the Visão Geral screen (Resumo Inteligente).
    static func dashboardOverviewSnapshot(
        summary: MonthSummary,
        overview: FinancialOverview,
        accounts: [Account],
        bills: [Bill],
        goals: [FinancialGoal],
        transactions: [Transaction],
        previousMonthExpense: Decimal,
        pendingBillsThisMonth: [Bill],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> String {
        let monthLabel = summary.referenceDate.formatted(.dateTime.month(.wide).year())
        var lines: [String] = []

        lines.append("=== VISÃO GERAL — \(monthLabel) ===")
        lines.append("")
        lines.append("PATRIMÔNIO")
        lines.append("- Patrimônio líquido: \(overview.netWorth.brl)")
        lines.append("- Disponível: \(overview.liquidBalance.brl)")
        if overview.debtBalance > 0 {
            lines.append("- Cartões (dívida): \(overview.debtBalance.brl)")
        }
        if overview.investmentBalance > 0 {
            lines.append("- Investido: \(overview.investmentBalance.brl)")
        }
        if overview.pendingBillsTotal > 0 {
            let overdueNote = overview.overdueBillsCount > 0
                ? " (\(overview.overdueBillsCount) vencida\(overview.overdueBillsCount == 1 ? "" : "s"))"
                : ""
            lines.append("- Contas a pagar pendentes: \(overview.pendingBillsTotal.brl)\(overdueNote)")
        }

        lines.append("")
        lines.append("FLUXO DO MÊS")
        lines.append("- Entrou: \(summary.totalIncome.brl)")
        lines.append("- Saiu: \(summary.totalExpense.brl)")
        lines.append("- Saldo do mês: \(summary.balance.brl)")
        lines.append("- Orçamento mensal: \(summary.monthlyIncomeBudget.brl)")
        if summary.hasPlanned {
            lines.append("- Previsto entrar: \(summary.plannedIncome.brl)")
            lines.append("- Previsto sair: \(summary.plannedExpense.brl)")
        }
        if summary.monthlyIncomeBudget > 0 || summary.totalIncome > 0 {
            lines.append("- Ritmo: \(summary.paceState.label) (\(Int(summary.spentRatio * 100))% do orçamento, \(Int(summary.dayProgress * 100))% do mês)")
            lines.append("- Dias restantes: \(summary.daysRemaining) | Orçamento diário restante: \(summary.dailyBudgetRemaining.brl)")
        }
        lines.append("- Despesas mês anterior: \(previousMonthExpense.brl)")

        let topCategories = summary.expensesByCategory.prefix(6)
        if !topCategories.isEmpty {
            lines.append("")
            lines.append("MAIORES CATEGORIAS (despesas)")
            for item in topCategories {
                let pct = summary.totalExpense > 0
                    ? Int(NSDecimalNumber(decimal: item.total / summary.totalExpense * 100).doubleValue)
                    : 0
                lines.append("- \(item.category.name): \(item.total.brl) (\(pct)%)")
            }
        }

        let accountExpenses = summary.expensesByAccount
        if !accountExpenses.isEmpty {
            lines.append("")
            lines.append("GASTOS POR CONTA")
            for item in accountExpenses {
                lines.append("- \(item.account.name): \(item.total.brl)")
            }
        }

        if !pendingBillsThisMonth.isEmpty {
            lines.append("")
            lines.append("CONTAS A PAGAR (vencimento neste mês)")
            for bill in pendingBillsThisMonth.sorted(by: { $0.dueDate < $1.dueDate }) {
                let status = bill.dueDate < now ? "VENCIDA" : "a vencer"
                lines.append("- \(bill.name): \(bill.amount.brl) | \(bill.dueDate.formatted(date: .abbreviated, time: .omitted)) | \(status)")
            }
        }

        let activeGoals = goals.filter { !$0.isCompleted }
        if !activeGoals.isEmpty {
            lines.append("")
            lines.append("METAS ATIVAS")
            for goal in activeGoals {
                let snapshot = GoalProgressCalculator.snapshot(
                    for: goal,
                    transactions: transactions,
                    asOf: summary.referenceDate,
                    calendar: calendar
                )
                lines.append("- \(goal.name): \(snapshot.currentAmount.brl) de \(snapshot.targetAmount.brl) (\(Int(snapshot.progress * 100))%)")
            }
        }

        if summary.investedThisMonth != 0 || overview.investmentBalance > 0 {
            lines.append("")
            lines.append("INVESTIMENTOS")
            if summary.investedThisMonth != 0 {
                lines.append("- Aportado no mês: \(summary.investedThisMonth.brl)")
            }
            if overview.investmentBalance > 0 {
                lines.append("- Total investido: \(overview.investmentBalance.brl)")
            }
        }

        lines.append("")
        lines.append("SALDOS POR CONTA")
        for account in accounts where !account.isArchived {
            let balance = account.currentBalance(considering: transactions, asOf: summary.referenceDate)
            lines.append("- \(account.name): \(balance.brl)")
        }

        lines.append("")
        lines.append("LANÇAMENTOS DO MÊS (realizados)")

        var transactionLines = summary.realizedMonthlyTransactions
            .sorted { $0.occurredOn > $1.occurredOn }
            .map { transactionLine($0) }

        var body = lines.joined(separator: "\n") + "\n"
        while !transactionLines.isEmpty {
            let candidate = body + transactionLines.joined(separator: "\n")
            if candidate.count <= maxCharacters { break }
            transactionLines.removeLast()
        }
        if transactionLines.isEmpty,
           let last = summary.realizedMonthlyTransactions.sorted(by: { $0.occurredOn > $1.occurredOn }).last {
            transactionLines = [transactionLine(last)]
        }
        body += transactionLines.joined(separator: "\n")
        return body
    }
}
