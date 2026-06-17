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
        DashboardCard(title: "Maiores dores",
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
        let tint: Color = isTop ? .red : .accentColor

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.16))
                        .frame(width: 26, height: 26)
                    Image(systemName: item.category.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(tint)
                }

                Text(item.category.name)
                    .font(.callout)

                Spacer()

                VStack(alignment: .trailing, spacing: 0) {
                    Text(item.total.brl)
                        .font(.callout.monospacedDigit().weight(.medium))
                    Text("\(item.count) \(item.count == 1 ? "lançamento" : "lançamentos") · \(percentFormatter.string(from: NSNumber(value: share)) ?? "")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(tint.opacity(0.7))
                        .frame(width: max(4, geo.size.width * ratio))
                }
            }
            .frame(height: 6)
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
