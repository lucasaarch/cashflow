import SwiftUI
import Charts
import SwiftData

// MARK: - Shared card header

private struct ChartCardHeader: View {
    let title: String
    let subtitle: String?
    @Binding var period: ReportPeriod

    private static let periodOptions: [CFSelectOption<ReportPeriod>] = ReportPeriod.allCases.map {
        CFSelectOption(id: $0, title: $0.label)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(CFTheme.headline())
                    .foregroundStyle(CFTheme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(CFTheme.caption())
                        .foregroundStyle(CFTheme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            CFSelectField(selection: $period, options: Self.periodOptions, popoverWidth: 180)
        }
    }
}

// MARK: - Individual chart cards (one per dashboard column)

struct DashboardCashFlowChartCard: View {
    let transactions: [Transaction]
    let accounts: [Account]
    let bills: [Bill]
    var chartHeight: CGFloat = 220

    @State private var period: ReportPeriod = .sixMonths

    private var report: ReportBuilder {
        ReportBuilder(period: period, transactions: transactions, accounts: accounts, bills: bills)
    }

    private var hasData: Bool {
        !report.cashFlowSeries.allSatisfy { $0.income == 0 && $0.expense == 0 }
    }

    var body: some View {
        if hasData {
            CFPanel {
                VStack(alignment: .leading, spacing: 12) {
                    ChartCardHeader(title: "Fluxo de caixa", subtitle: "Receita vs despesa por mês", period: $period)
                    Chart(report.cashFlowSeries) { point in
                        BarMark(
                            x: .value("Mês", point.month, unit: .month),
                            y: .value("Receita", NSDecimalNumber(decimal: point.income).doubleValue)
                        )
                        .foregroundStyle(CFTheme.income)
                        .position(by: .value("Tipo", "Receita"))

                        BarMark(
                            x: .value("Mês", point.month, unit: .month),
                            y: .value("Despesa", NSDecimalNumber(decimal: point.expense).doubleValue)
                        )
                        .foregroundStyle(CFTheme.expense)
                        .position(by: .value("Tipo", "Despesa"))
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Money.locale))
                        }
                    }
                    .chartLegend(position: .top, alignment: .trailing)
                    .frame(height: chartHeight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct DashboardNetWorthChartCard: View {
    let transactions: [Transaction]
    let accounts: [Account]
    let bills: [Bill]
    var chartHeight: CGFloat = 220

    @State private var period: ReportPeriod = .sixMonths

    private var report: ReportBuilder {
        ReportBuilder(period: period, transactions: transactions, accounts: accounts, bills: bills)
    }

    private var hasData: Bool {
        !report.netWorthSeries.allSatisfy { $0.netWorth == 0 }
    }

    var body: some View {
        if hasData {
            CFPanel {
                VStack(alignment: .leading, spacing: 12) {
                    ChartCardHeader(title: "Patrimônio", subtitle: "Evolução no período", period: $period)
                    Chart(report.netWorthSeries) { point in
                        LineMark(
                            x: .value("Mês", point.month, unit: .month),
                            y: .value("Patrimônio", NSDecimalNumber(decimal: point.netWorth).doubleValue)
                        )
                        .foregroundStyle(CFTheme.accent)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Mês", point.month, unit: .month),
                            y: .value("Patrimônio", NSDecimalNumber(decimal: point.netWorth).doubleValue)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [CFTheme.accent.opacity(0.22), CFTheme.accent.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Money.locale))
                        }
                    }
                    .frame(height: chartHeight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct DashboardInvestmentsChartCard: View {
    let transactions: [Transaction]
    let accounts: [Account]
    let bills: [Bill]
    var chartHeight: CGFloat = 180

    @State private var period: ReportPeriod = .sixMonths

    private var report: ReportBuilder {
        ReportBuilder(period: period, transactions: transactions, accounts: accounts, bills: bills)
    }

    private var hasData: Bool {
        !report.investmentFlowSeries.allSatisfy { $0.netInvested == 0 }
    }

    var body: some View {
        if hasData {
            CFPanel {
                VStack(alignment: .leading, spacing: 12) {
                    ChartCardHeader(title: "Aportes e resgates", subtitle: "Líquido por mês", period: $period)
                    Chart(report.investmentFlowSeries) { point in
                        BarMark(
                            x: .value("Mês", point.month, unit: .month),
                            y: .value("Líquido", NSDecimalNumber(decimal: point.netInvested).doubleValue)
                        )
                        .foregroundStyle(point.netInvested >= 0 ? CFTheme.accent : CFTheme.warning)
                        .cornerRadius(4)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).locale(Money.locale))
                        }
                    }
                    .frame(height: chartHeight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
