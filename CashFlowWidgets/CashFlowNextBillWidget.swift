import WidgetKit
import SwiftUI

struct CashFlowNextBillWidget: Widget {
    let kind = "CashFlowNextBillWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CashFlowNextBillProvider()) { entry in
            CashFlowNextBillWidgetView(entry: entry)
        }
        .configurationDisplayName("Próxima conta")
        .description("Mostra a próxima conta a pagar.")
        .supportedFamilies(supportedFamilies)
    }

    private var supportedFamilies: [WidgetFamily] {
        #if os(iOS)
        [.systemSmall, .accessoryRectangular]
        #else
        [.systemSmall]
        #endif
    }
}

struct CashFlowNextBillEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct CashFlowNextBillProvider: TimelineProvider {
    func placeholder(in context: Context) -> CashFlowNextBillEntry {
        CashFlowNextBillEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CashFlowNextBillEntry) -> Void) {
        completion(CashFlowNextBillEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CashFlowNextBillEntry>) -> Void) {
        let entry = CashFlowNextBillEntry(date: .now, snapshot: WidgetSnapshotStore.load() ?? .empty)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

struct CashFlowNextBillWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CashFlowNextBillEntry

    private var hidden: Bool { entry.snapshot.valuesHidden }
    private var hasBill: Bool { entry.snapshot.nextBillName != nil && entry.snapshot.nextBillAmountMinorUnits != nil }

    var body: some View {
        Group {
            #if os(iOS)
            if family == .accessoryRectangular {
                accessoryView
            } else {
                smallView
            }
            #else
            smallView
            #endif
        }
        .containerBackground(for: .widget) {
            Color(red: 36 / 255, green: 41 / 255, blue: 43 / 255)
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Próxima conta", systemImage: "calendar.badge.clock")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
            if hasBill, let name = entry.snapshot.nextBillName {
                Text(name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let amount = entry.snapshot.nextBillAmountMinorUnits {
                    Text(WidgetMoneyFormat.brl(minorUnits: amount, hidden: hidden))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(entry.snapshot.nextBillIsOverdue ? Color.red : Color(red: 0.350, green: 0.650, blue: 1.000))
                }
                if let due = entry.snapshot.nextBillDueDate {
                    Text(WidgetMoneyFormat.dueLabel(for: due))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.65))
                }
            } else {
                Text("Nenhuma conta pendente")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
    }

    private var accessoryView: some View {
        HStack {
            if hasBill, let name = entry.snapshot.nextBillName, let amount = entry.snapshot.nextBillAmountMinorUnits {
                VStack(alignment: .leading) {
                    Text(name).lineLimit(1)
                    Text(WidgetMoneyFormat.brl(minorUnits: amount, hidden: hidden))
                }
            } else {
                Text("Sem contas")
            }
        }
    }
}
