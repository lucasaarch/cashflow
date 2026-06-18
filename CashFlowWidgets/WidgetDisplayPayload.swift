import Foundation

// Keep in sync with CashFlow/Shared/Widgets/WidgetDisplayPayload.swift

struct WidgetDisplayPayload: Codable, Sendable, Equatable {
    var updatedAt: Date
    var netWorth: String
    var liquid: String
    var invested: String
    var nextBillName: String?
    var nextBillAmount: String?
    var nextBillDue: String?
    var netWorthCompact: String
    var liquidCompact: String
    var valuesHidden: Bool

    var hasContent: Bool {
        updatedAt > .distantPast && (!netWorth.isEmpty || !liquid.isEmpty)
    }

    static func make(from snapshot: WidgetSnapshot) -> WidgetDisplayPayload {
        let hidden = snapshot.valuesHidden
        return WidgetDisplayPayload(
            updatedAt: snapshot.updatedAt,
            netWorth: WidgetMoneyFormat.brl(minorUnits: snapshot.netWorthMinorUnits, hidden: hidden),
            liquid: WidgetMoneyFormat.brl(minorUnits: snapshot.liquidBalanceMinorUnits, hidden: hidden),
            invested: WidgetMoneyFormat.brl(minorUnits: snapshot.totalInvestedMinorUnits, hidden: hidden),
            nextBillName: snapshot.nextBillName,
            nextBillAmount: snapshot.nextBillAmountMinorUnits.map {
                WidgetMoneyFormat.brl(minorUnits: $0, hidden: hidden)
            },
            nextBillDue: snapshot.nextBillDueDate.map(WidgetMoneyFormat.dueLabel(for:)),
            netWorthCompact: WidgetMoneyFormat.compactBRL(minorUnits: snapshot.netWorthMinorUnits, hidden: hidden),
            liquidCompact: WidgetMoneyFormat.compactBRL(minorUnits: snapshot.liquidBalanceMinorUnits, hidden: hidden),
            valuesHidden: hidden
        )
    }
}
