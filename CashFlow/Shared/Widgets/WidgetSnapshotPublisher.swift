import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum WidgetSnapshotPublisher {
    static func publish(
        accounts: [Account],
        transactions: [Transaction],
        bills: [Bill],
        valuesHidden: Bool
    ) {
        let overview = FinancialOverview(
            accounts: accounts,
            transactions: transactions,
            bills: bills
        )

        let pendingBills = bills
            .filter(\.isPending)
            .sorted { lhs, rhs in
                if lhs.isOverdue() != rhs.isOverdue() { return lhs.isOverdue() }
                return lhs.dueDate < rhs.dueDate
            }

        let nextBill = pendingBills.first

        let snapshot = WidgetSnapshot(
            updatedAt: .now,
            netWorthMinorUnits: overview.netWorth.minorUnits,
            liquidBalanceMinorUnits: overview.liquidBalance.minorUnits,
            totalInvestedMinorUnits: overview.totalInvestedBalance.minorUnits,
            pendingBillsTotalMinorUnits: overview.pendingBillsTotal.minorUnits,
            overdueBillsCount: overview.overdueBillsCount,
            nextBillName: nextBill?.name,
            nextBillAmountMinorUnits: nextBill.map { $0.amount.minorUnits },
            nextBillDueDate: nextBill?.dueDate,
            nextBillIsOverdue: nextBill?.isOverdue() ?? false,
            valuesHidden: valuesHidden
        )

        WidgetSnapshotStore.save(snapshot)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "CashFlowOverviewWidget")
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
