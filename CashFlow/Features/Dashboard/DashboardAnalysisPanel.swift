import SwiftUI

struct DashboardAnalysisPanel: View {
    let categoryAggregates: [MonthSummary.CategoryAggregate]
    let accountAggregates: [MonthSummary.AccountAggregate]
    let totalExpense: Decimal

    private var hasCategories: Bool { !categoryAggregates.isEmpty }
    private var hasAccounts: Bool { !accountAggregates.isEmpty }

    var shouldShow: Bool { hasCategories || hasAccounts }

    var body: some View {
        CFPanel {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    if hasCategories {
                        CategoryBreakdownContent(
                            aggregates: categoryAggregates,
                            totalExpense: totalExpense
                        )
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    if hasCategories && hasAccounts {
                        Divider()
                    }
                    if hasAccounts {
                        AccountBreakdownContent(aggregates: accountAggregates)
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                }
                VStack(alignment: .leading, spacing: 16) {
                    if hasCategories {
                        CategoryBreakdownContent(
                            aggregates: categoryAggregates,
                            totalExpense: totalExpense
                        )
                    }
                    if hasCategories && hasAccounts {
                        CFPanelDivider()
                    }
                    if hasAccounts {
                        AccountBreakdownContent(aggregates: accountAggregates)
                    }
                }
            }
        }
    }
}

struct CategoryBreakdownContent: View {
    let aggregates: [MonthSummary.CategoryAggregate]
    let totalExpense: Decimal

    private var visible: [MonthSummary.CategoryAggregate] {
        Array(aggregates.prefix(6))
    }

    private var maxTotal: Decimal {
        aggregates.first?.total ?? 0
    }

    var body: some View {
        CFPanelSection(
            title: "Maiores dores",
            subtitle: "Por categoria"
        ) {
            VStack(spacing: 10) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                    categoryRow(item, isTop: index == 0)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryRow(_ item: MonthSummary.CategoryAggregate, isTop: Bool) -> some View {
        let ratio = ratioOfMax(item.total)
        let share = ratioOfTotal(item.total)

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(item.category.name)
                    .font(.callout.weight(isTop ? .semibold : .regular))
                    .lineLimit(1)
                Spacer()
                Text(item.total.brl)
                    .font(.caption.monospacedDigit().weight(.medium))
                Text(percentFormatter.string(from: NSNumber(value: share)) ?? "")
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textTertiary)
                    .frame(width: 32, alignment: .trailing)
            }
            CFProgressBar(progress: ratio, color: CFTheme.expense.opacity(isTop ? 1 : 0.7), height: 4)
        }
    }

    private func ratioOfMax(_ value: Decimal) -> CGFloat {
        guard maxTotal > 0 else { return 0 }
        return CGFloat(NSDecimalNumber(decimal: value / maxTotal).doubleValue)
    }

    private func ratioOfTotal(_ value: Decimal) -> Double {
        guard totalExpense > 0 else { return 0 }
        return NSDecimalNumber(decimal: value / totalExpense).doubleValue
    }

    private var percentFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .percent
        f.maximumFractionDigits = 0
        return f
    }
}

struct AccountBreakdownContent: View {
    let aggregates: [MonthSummary.AccountAggregate]

    var body: some View {
        CFPanelSection(title: "Por conta", subtitle: "Forma de pagamento") {
            VStack(spacing: 6) {
                ForEach(aggregates) { item in
                    accountRow(item)
                }
            }
        }
    }

    @ViewBuilder
    private func accountRow(_ item: MonthSummary.AccountAggregate) -> some View {
        let isCard = item.account.kind == .creditCard
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: item.account.colorHex))
                .frame(width: 8, height: 8)
            Text(item.account.name)
                .font(.callout)
                .lineLimit(1)
            Spacer()
            Text(item.total.brl)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(isCard ? CFTheme.debt : CFTheme.textPrimary)
        }
    }
}

// Legacy wrappers for any external use
struct CategoryBreakdownCard: View {
    let aggregates: [MonthSummary.CategoryAggregate]
    let totalExpense: Decimal

    var body: some View {
        CFPanel {
            CategoryBreakdownContent(aggregates: aggregates, totalExpense: totalExpense)
        }
    }
}

struct AccountBreakdownCard: View {
    let aggregates: [MonthSummary.AccountAggregate]

    var body: some View {
        CFPanel {
            AccountBreakdownContent(aggregates: aggregates)
        }
    }
}
