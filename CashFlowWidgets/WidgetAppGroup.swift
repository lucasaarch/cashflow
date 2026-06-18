import Foundation

enum WidgetAppGroup {
    static let identifier = "group.com.lucasarch.CashFlow"
    static let snapshotKey = "widget.snapshot"
    static let displayFileName = "widget-display.json"

    enum FlatKey {
        static let hasData = "widget.hasData"
        static let updatedAt = "widget.updatedAt"
        static let netWorthMinorUnits = "widget.netWorthMinorUnits"
        static let liquidBalanceMinorUnits = "widget.liquidBalanceMinorUnits"
        static let totalInvestedMinorUnits = "widget.totalInvestedMinorUnits"
        static let pendingBillsTotalMinorUnits = "widget.pendingBillsTotalMinorUnits"
        static let overdueBillsCount = "widget.overdueBillsCount"
        static let nextBillName = "widget.nextBillName"
        static let nextBillAmountMinorUnits = "widget.nextBillAmountMinorUnits"
        static let nextBillDueDate = "widget.nextBillDueDate"
        static let nextBillIsOverdue = "widget.nextBillIsOverdue"
        static let valuesHidden = "widget.valuesHidden"
        static let netWorthDisplay = "widget.netWorthDisplay"
        static let liquidDisplay = "widget.liquidDisplay"
        static let investedDisplay = "widget.investedDisplay"
        static let nextBillAmountDisplay = "widget.nextBillAmountDisplay"
        static let nextBillDueDisplay = "widget.nextBillDueDisplay"
    }
}
