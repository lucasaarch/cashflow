import SwiftUI

struct DashboardCategoryTrendsPanel: View {
    let currentSummary: MonthSummary
    let previousSummary: MonthSummary

    @EnvironmentObject private var privacy: PrivacyMode

    private var rows: [CategoryTrendRow] {
        let previousByID = Dictionary(uniqueKeysWithValues: previousSummary.expensesByCategory.map { ($0.category.id, $0) })
        let currentByID = Dictionary(uniqueKeysWithValues: currentSummary.expensesByCategory.map { ($0.category.id, $0) })
        let ids = Set(previousByID.keys).union(currentByID.keys)

        return ids.compactMap { id in
            let current = currentByID[id]
            let previous = previousByID[id]
            guard let category = current?.category ?? previous?.category else { return nil }
            let currentTotal = current?.total ?? 0
            let previousTotal = previous?.total ?? 0
            guard currentTotal > 0 || previousTotal > 0 else { return nil }
            return CategoryTrendRow(category: category, current: currentTotal, previous: previousTotal)
        }
        .filter { abs($0.delta) >= 1 }
        .sorted { lhs, rhs in
            if lhs.isIncrease != rhs.isIncrease { return lhs.isIncrease }
            return abs(lhs.delta) > abs(rhs.delta)
        }
        .prefix(4)
        .map { $0 }
    }

    var body: some View {
        if !rows.isEmpty {
            CFPanel {
                CFPanelSection(title: "Comparativo por categoria", subtitle: "Mês atual vs. mês anterior") {
                    VStack(spacing: 12) {
                        ForEach(rows) { row in
                            trendRow(row)
                        }
                    }
                }
            }
        }
    }

    private func trendRow(_ row: CategoryTrendRow) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Image(systemName: row.category.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(row.tint)
                    .frame(width: 18)
                Text(row.category.name)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(CFTheme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(row.deltaLabel(masked: privacy.valuesHidden))
                    .font(CFTheme.dashboardAmount())
                    .foregroundStyle(row.tint)
                    .lineLimit(1)
            }

            CategoryTrendBars(row: row)

            HStack(spacing: 8) {
                Text("Anterior \(row.previous.brl(masked: privacy.valuesHidden))")
                Spacer(minLength: 8)
                Text("Atual \(row.current.brl(masked: privacy.valuesHidden))")
            }
            .font(CFTheme.dashboardMeta().monospacedDigit())
            .foregroundStyle(CFTheme.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

private struct CategoryTrendBars: View {
    let row: CategoryTrendRow

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let maxAmount = max(row.current, row.previous, 1)
            let previousWidth = width * ratio(row.previous, maxAmount: maxAmount)
            let currentWidth = width * ratio(row.current, maxAmount: maxAmount)

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(CFTheme.textTertiary.opacity(0.18))
                    .frame(width: previousWidth, height: 5)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(row.tint)
                    .frame(width: currentWidth, height: 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 15)
    }

    private func ratio(_ amount: Decimal, maxAmount: Decimal) -> CGFloat {
        guard maxAmount > 0 else { return 0 }
        let value = NSDecimalNumber(decimal: amount / maxAmount).doubleValue
        return CGFloat(min(max(value, 0.04), 1))
    }
}

private struct CategoryTrendRow: Identifiable {
    let category: Category
    let current: Decimal
    let previous: Decimal

    var id: UUID { category.id }
    var delta: Decimal { current - previous }
    var isIncrease: Bool { delta > 0 }

    var tint: Color {
        if delta > 0 { return CFTheme.danger }
        if delta < 0 { return CFTheme.income }
        return CFTheme.textSecondary
    }

    func deltaLabel(masked: Bool) -> String {
        if previous > 0 {
            let percent = NSDecimalNumber(decimal: abs(delta) / previous * 100).intValue
            let direction = delta >= 0 ? "+" : "-"
            return "\(direction)\(percent)%"
        }
        if current > 0 { return "novo gasto" }
        return "sem variação"
    }
}
