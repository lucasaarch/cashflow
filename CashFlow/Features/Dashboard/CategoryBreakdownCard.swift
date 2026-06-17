import SwiftUI

struct CategoryBreakdownCard: View {
    let aggregates: [MonthSummary.CategoryAggregate]
    let totalExpense: Decimal

    private var visible: [MonthSummary.CategoryAggregate] {
        Array(aggregates.prefix(8))
    }

    private var maxTotal: Decimal {
        aggregates.first?.total ?? 0
    }

    var body: some View {
        CFGlassCard(title: "Maiores dores",
                    subtitle: aggregates.isEmpty
                      ? "Cadastre alguns gastos pra ver onde está vazando"
                      : "Categorias que mais consumiram seu dinheiro este mês") {
            if aggregates.isEmpty {
                emptyState
            } else {
                VStack(spacing: 14) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                        row(item, isTop: index == 0)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Image(systemName: "tray")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("Sem despesas neste mês ainda.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.callout)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func row(_ item: MonthSummary.CategoryAggregate, isTop: Bool) -> some View {
        let ratio = ratioOfMax(item.total)
        let share = ratioOfTotal(item.total)
        let tint: Color = CFTheme.expense

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                CFIconBadge(
                    symbolName: item.category.symbolName,
                    tint: tint,
                    size: 26
                )

                Text(item.category.name)
                    .font(.callout.weight(isTop ? .semibold : .regular))
                    .foregroundStyle(CFTheme.textPrimary)

                if isTop {
                    Text("Top 1")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(CFTheme.expense)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(CFTheme.expense.opacity(0.14))
                        )
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    CFAnimatedAmount(
                        amount: item.total,
                        font: .callout.monospacedDigit().weight(.medium),
                        color: CFTheme.textPrimary
                    )
                    Text("\(item.count) \(item.count == 1 ? "lançamento" : "lançamentos") · \(percentFormatter.string(from: NSNumber(value: share)) ?? "")")
                        .font(.caption2)
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }

            CFProgressBar(progress: ratio, color: tint.opacity(isTop ? 1.0 : 0.78), height: 6)
            .frame(height: 6)
        }
        .padding(.vertical, 2)
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
