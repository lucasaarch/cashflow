import Foundation

/// Point-in-time financial snapshot (balances, patrimônio).
struct FinancialOverview {
    let liquidBalance: Decimal
    let debtBalance: Decimal
    let investmentBalance: Decimal
    let goalReservedBalance: Decimal
    let netWorth: Decimal
    let pendingBillsTotal: Decimal
    let overdueBillsCount: Int

    /// Investimentos + saldo reservado em metas.
    var totalInvestedBalance: Decimal { investmentBalance + goalReservedBalance }

    init(
        accounts: [Account],
        transactions: [Transaction],
        bills: [Bill] = [],
        asOf: Date = .now,
        now: Date = .now
    ) {
        let active = accounts.filter { !$0.isArchived }

        liquidBalance = active
            .filter { $0.kind.isLiquid }
            .reduce(0) { $0 + $1.currentBalance(considering: transactions, asOf: asOf) }

        debtBalance = active
            .filter { $0.kind == .creditCard }
            .reduce(0) { $0 + abs(min($1.currentBalance(considering: transactions, asOf: asOf), 0)) }

        investmentBalance = active
            .filter { $0.kind == .investment }
            .reduce(0) { $0 + max($1.currentBalance(considering: transactions, asOf: asOf), 0) }

        goalReservedBalance = active
            .filter { $0.kind == .goal }
            .reduce(0) { $0 + max($1.currentBalance(considering: transactions, asOf: asOf), 0) }

        netWorth = liquidBalance - debtBalance + investmentBalance + goalReservedBalance

        let pending = bills.filter { $0.isPending }
        pendingBillsTotal = pending.reduce(0) { $0 + $1.amount }
        overdueBillsCount = pending.filter { $0.dueDate < now }.count
    }
}
