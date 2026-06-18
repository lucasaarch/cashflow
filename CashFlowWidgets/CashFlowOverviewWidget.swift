import WidgetKit
import SwiftUI

struct CashFlowOverviewWidget: Widget {
    let kind = "CashFlowOverviewWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CashFlowOverviewProvider()) { entry in
            CashFlowOverviewWidgetView(entry: entry)
        }
        .configurationDisplayName("CashFlow")
        .description("Patrimônio, saldo disponível e próxima conta a pagar.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline]
        #else
        [.systemSmall, .systemMedium]
        #endif
    }
}

struct CashFlowOverviewEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let display: WidgetDisplayPayload?
}

struct CashFlowOverviewProvider: TimelineProvider {
    func placeholder(in context: Context) -> CashFlowOverviewEntry {
        CashFlowOverviewEntry(date: .now, snapshot: .placeholder, display: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (CashFlowOverviewEntry) -> Void) {
        completion(resolvedEntry(isPreview: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CashFlowOverviewEntry>) -> Void) {
        let entry = resolvedEntry(isPreview: context.isPreview)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: .now) ?? .now.addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func resolvedEntry(isPreview: Bool) -> CashFlowOverviewEntry {
        if isPreview {
            return CashFlowOverviewEntry(date: .now, snapshot: .placeholder, display: nil)
        }
        let snapshot = WidgetSnapshotStore.load() ?? .empty
        let display = WidgetSnapshotStore.loadDisplay()
        return CashFlowOverviewEntry(date: .now, snapshot: snapshot, display: display)
    }
}

private enum WidgetPalette {
    /// Matches `SurfacePrimary` dark in the main app (#24292B).
    static let surfacePrimary = Color(red: 36 / 255, green: 41 / 255, blue: 43 / 255)
    static let accent = Color(red: 0.350, green: 0.650, blue: 1.000)
    static let warning = Color(red: 0.984, green: 0.749, blue: 0.141)
    static let danger = Color(red: 0.937, green: 0.267, blue: 0.267)
}

private struct WidgetResolvedContent {
    let snapshot: WidgetSnapshot
    let display: WidgetDisplayPayload?

    init(snapshot: WidgetSnapshot, display: WidgetDisplayPayload?) {
        self.snapshot = snapshot
        self.display = display
    }

    var hidden: Bool { display?.valuesHidden ?? snapshot.valuesHidden }

    var hasContent: Bool {
        if let display, display.hasContent { return true }
        guard snapshot.hasData else { return false }
        return hidden
            || snapshot.netWorthMinorUnits != 0
            || snapshot.liquidBalanceMinorUnits != 0
            || snapshot.totalInvestedMinorUnits != 0
    }

    var netWorthText: String {
        display?.netWorth ?? WidgetMoneyFormat.brl(minorUnits: snapshot.netWorthMinorUnits, hidden: hidden)
    }

    var liquidText: String {
        display?.liquid ?? WidgetMoneyFormat.brl(minorUnits: snapshot.liquidBalanceMinorUnits, hidden: hidden)
    }

    var investedText: String {
        display?.invested ?? WidgetMoneyFormat.brl(minorUnits: snapshot.totalInvestedMinorUnits, hidden: hidden)
    }

    var netWorthCompactText: String {
        display?.netWorthCompact ?? WidgetMoneyFormat.compactBRL(minorUnits: snapshot.netWorthMinorUnits, hidden: hidden)
    }

    var liquidCompactText: String {
        display?.liquidCompact ?? WidgetMoneyFormat.compactBRL(minorUnits: snapshot.liquidBalanceMinorUnits, hidden: hidden)
    }

    var netWorthIsNegative: Bool {
        if let display, display.netWorth.hasPrefix("-") { return true }
        return snapshot.netWorthMinorUnits < 0
    }

    var nextBillName: String? { display?.nextBillName ?? snapshot.nextBillName }

    var nextBillAmountText: String? {
        if let displayAmount = display?.nextBillAmount { return displayAmount }
        guard let amount = snapshot.nextBillAmountMinorUnits else { return nil }
        return WidgetMoneyFormat.brl(minorUnits: amount, hidden: hidden)
    }

    var nextBillDueText: String? {
        if let due = display?.nextBillDue, !due.isEmpty { return due }
        guard let date = snapshot.nextBillDueDate else { return nil }
        return WidgetMoneyFormat.dueLabel(for: date)
    }

    var showsNextBill: Bool {
        nextBillName != nil && nextBillAmountText != nil
    }
}

private struct WidgetAdaptiveColors {
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let accent: Color
    let danger: Color
    let warning: Color

    static let monochrome = WidgetAdaptiveColors(
        primary: .white,
        secondary: Color.white.opacity(0.72),
        tertiary: Color.white.opacity(0.52),
        accent: .white,
        danger: .white,
        warning: .white
    )

    static let fullColor = WidgetAdaptiveColors(
        primary: .white,
        secondary: Color.white.opacity(0.72),
        tertiary: Color.white.opacity(0.52),
        accent: WidgetPalette.accent,
        danger: WidgetPalette.danger,
        warning: WidgetPalette.warning
    )
}

struct CashFlowOverviewWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: CashFlowOverviewEntry

    private var content: WidgetResolvedContent {
        let snapshot = WidgetSnapshotStore.load() ?? entry.snapshot
        let display = WidgetSnapshotStore.loadDisplay() ?? entry.display
        return WidgetResolvedContent(snapshot: snapshot, display: display)
    }

    private var colors: WidgetAdaptiveColors {
        switch renderingMode {
        case .fullColor:
            return .fullColor
        case .accented, .vibrant:
            return .monochrome
        default:
            return .monochrome
        }
    }

    private var usesSystemGlassBackground: Bool {
        renderingMode != .fullColor
    }

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                smallView
            case .systemMedium:
                mediumView
            case .accessoryRectangular:
                accessoryRectangularView
            case .accessoryCircular:
                accessoryCircularView
            case .accessoryInline:
                accessoryInlineView
            default:
                smallView
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
    }

    @ViewBuilder
    private var widgetBackground: some View {
        if usesSystemGlassBackground {
            // Clear/Tinted desktop — system composites Liquid Glass over the wallpaper.
            Color.clear
        } else {
            // Full Color (desktop default) — solid card, same charcoal as the app.
            ContainerRelativeShape()
                .fill(WidgetPalette.surfacePrimary)
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Patrimônio", systemImage: "chart.pie.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(colors.secondary)
                .labelStyle(.titleAndIcon)
                .widgetAccentableWhen(usesSystemGlassBackground)

            if content.hasContent {
                Text(content.netWorthText)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(content.netWorthIsNegative ? colors.danger : colors.primary)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .widgetAccentableWhen(usesSystemGlassBackground && content.netWorthIsNegative)

                Spacer(minLength: 0)

                metricRow(
                    icon: "building.columns.fill",
                    label: "Disponível",
                    value: content.liquidText,
                    accent: usesSystemGlassBackground
                )
            } else {
                Text("Abra o CashFlow")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(colors.secondary)
                Spacer(minLength: 0)
                Text("Para atualizar o widget")
                    .font(.caption)
                    .foregroundStyle(colors.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Patrimônio líquido")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(colors.secondary)
                    .textCase(.uppercase)

                if content.hasContent {
                    Text(content.netWorthText)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(content.netWorthIsNegative ? colors.danger : colors.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .widgetAccentableWhen(usesSystemGlassBackground && content.netWorthIsNegative)

                    VStack(alignment: .leading, spacing: 6) {
                        metricRow(
                            icon: "building.columns.fill",
                            label: "Disponível",
                            value: content.liquidText,
                            accent: usesSystemGlassBackground
                        )
                        metricRow(
                            icon: "chart.line.uptrend.xyaxis",
                            label: "Investido",
                            value: content.investedText,
                            accent: usesSystemGlassBackground
                        )
                    }
                } else {
                    Text("Abra o CashFlow")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(colors.primary)
                    Text("Os dados aparecem depois que o app sincroniza neste Mac.")
                        .font(.caption)
                        .foregroundStyle(colors.secondary)
                }
            }

            Spacer(minLength: 0)

            if content.hasContent, content.showsNextBill,
               let name = content.nextBillName,
               let amount = content.nextBillAmountText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Próxima conta")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(colors.secondary)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(colors.primary)
                            .lineLimit(2)

                        Text(amount)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(entry.snapshot.nextBillIsOverdue ? colors.danger : colors.warning)
                            .widgetAccentableWhen(usesSystemGlassBackground)

                        if let due = content.nextBillDueText {
                            Text(due)
                                .font(.caption2)
                                .foregroundStyle(entry.snapshot.nextBillIsOverdue ? colors.danger : colors.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Patrimônio \(content.netWorthCompactText)")
                .font(.headline)
            Text("Disp. \(content.liquidCompactText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(content.netWorthCompactText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }

    private var accessoryInlineView: some View {
        Text("CashFlow \(content.netWorthCompactText)")
    }

    private func metricRow(icon: String, label: String, value: String, accent: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(colors.accent)
                .frame(width: 14)
                .widgetAccentableWhen(accent)

            Text(label)
                .font(.caption)
                .foregroundStyle(colors.secondary)

            Spacer(minLength: 4)

            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(colors.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .widgetAccentableWhen(accent)
        }
    }
}

private extension View {
    @ViewBuilder
    func widgetAccentableWhen(_ enabled: Bool = true) -> some View {
        if enabled {
            widgetAccentable()
        } else {
            self
        }
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    CashFlowOverviewWidget()
} timeline: {
    CashFlowOverviewEntry(date: .now, snapshot: .placeholder, display: nil)
}

#Preview(as: .systemMedium) {
    CashFlowOverviewWidget()
} timeline: {
    CashFlowOverviewEntry(date: .now, snapshot: .placeholder, display: nil)
}
#endif
