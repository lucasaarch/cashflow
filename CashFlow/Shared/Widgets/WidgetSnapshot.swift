import Foundation

struct WidgetSnapshot: Codable, Sendable, Equatable {
    var updatedAt: Date
    var netWorthMinorUnits: Int64
    var liquidBalanceMinorUnits: Int64
    var totalInvestedMinorUnits: Int64
    var pendingBillsTotalMinorUnits: Int64
    var overdueBillsCount: Int
    var nextBillName: String?
    var nextBillAmountMinorUnits: Int64?
    var nextBillDueDate: Date?
    var nextBillIsOverdue: Bool
    var valuesHidden: Bool

    static let placeholder = WidgetSnapshot(
        updatedAt: .now,
        netWorthMinorUnits: 1_500_000,
        liquidBalanceMinorUnits: 18_446,
        totalInvestedMinorUnits: 1_400_000,
        pendingBillsTotalMinorUnits: 79_300,
        overdueBillsCount: 0,
        nextBillName: "Aluguel",
        nextBillAmountMinorUnits: 79_300,
        nextBillDueDate: .now,
        nextBillIsOverdue: false,
        valuesHidden: false
    )

    static let empty = WidgetSnapshot(
        updatedAt: .distantPast,
        netWorthMinorUnits: 0,
        liquidBalanceMinorUnits: 0,
        totalInvestedMinorUnits: 0,
        pendingBillsTotalMinorUnits: 0,
        overdueBillsCount: 0,
        nextBillName: nil,
        nextBillAmountMinorUnits: nil,
        nextBillDueDate: nil,
        nextBillIsOverdue: false,
        valuesHidden: false
    )

    var hasData: Bool {
        updatedAt > .distantPast
    }
}

extension Decimal {
    var minorUnits: Int64 {
        var value = self
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return (rounded as NSDecimalNumber).multiplying(by: 100).int64Value
    }

    init(minorUnits: Int64) {
        self = Decimal(minorUnits) / 100
    }
}
