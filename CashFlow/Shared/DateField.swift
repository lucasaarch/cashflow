import SwiftUI

struct DateField: View {
    @Binding var date: Date
    @State private var showingPopover = false

    private var yesterday: Date {
        Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now
    }

    private enum QuickDate: Hashable {
        case today
        case yesterday
        case other
    }

    private var quickDate: QuickDate {
        if Calendar.current.isDateInToday(date) { return .today }
        if Calendar.current.isDateInYesterday(date) { return .yesterday }
        return .other
    }

    var body: some View {
        Button {
            showingPopover = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CFTheme.textSecondary)
                Text(displayString)
                    .foregroundStyle(CFTheme.textPrimary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(CFTheme.textTertiary)
            }
            .cfPickerChip()
        }
        .buttonStyle(.plain)
        .cfAdaptivePicker(isPresented: $showingPopover, arrowEdge: .bottom, sheetTitle: "Data") {
            popoverContent
        }
    }

    private var popoverContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                quickButton("Hoje", isSelected: quickDate == .today) {
                    date = .now
                }
                quickButton("Ontem", isSelected: quickDate == .yesterday) {
                    date = yesterday
                }
            }
            .padding(12)

            Divider().opacity(0.35)

            CFMonthCalendar(date: $date)
        }
        .frame(width: 280)
    }

    private func quickButton(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? CFTheme.accent.opacity(0.18) : CFTheme.textTertiary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(isSelected ? CFTheme.accent.opacity(0.35) : .clear, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? CFTheme.accent : CFTheme.textPrimary)
        }
        .buttonStyle(.plain)
    }

    private var displayString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoje" }
        if calendar.isDateInYesterday(date) { return "Ontem" }
        return date.formatted(.dateTime.day().month(.abbreviated).year().locale(Money.locale))
    }
}

// MARK: - Custom calendar (avoids native DatePicker focus ring)

private struct CFMonthCalendar: View {
    @Binding var date: Date
    @State private var displayedMonth: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    init(date: Binding<Date>) {
        _date = date
        _displayedMonth = State(initialValue: date.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 10) {
            monthHeader
            weekdayHeader
            daysGrid
        }
        .padding(12)
        .onChange(of: date) { _, newValue in
            if !calendar.isDate(newValue, equalTo: displayedMonth, toGranularity: .month) {
                displayedMonth = newValue
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(CFTheme.textSecondary)

            Spacer()

            Text(monthTitle)
                .font(.callout.weight(.semibold))
                .foregroundStyle(CFTheme.textPrimary)

            Spacer()

            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(CFTheme.textSecondary)
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(CFTheme.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var daysGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(gridDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayButton(day)
                } else {
                    Color.clear.frame(height: 32)
                }
            }
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: date)
        let isToday = calendar.isDateInToday(day)
        let inMonth = calendar.isDate(day, equalTo: displayedMonth, toGranularity: .month)

        return Button {
            date = calendar.startOfDay(for: day)
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.callout.weight(isSelected ? .semibold : .regular))
                .monospacedDigit()
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(isSelected ? CFTheme.accent : .clear)
                )
                .overlay(
                    Circle()
                        .stroke(isToday && !isSelected ? CFTheme.accent.opacity(0.5) : .clear, lineWidth: 1.5)
                )
                .foregroundStyle(isSelected ? .white : (inMonth ? CFTheme.textPrimary : CFTheme.textTertiary.opacity(0.45)))
        }
        .buttonStyle(.plain)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year().locale(Money.locale)).capitalized
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...]) + Array(symbols[..<start])
    }

    private var gridDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: displayedMonth)
        else { return [] }

        let firstOfMonth = monthInterval.start
        let leading = (calendar.component(.weekday, from: firstOfMonth) - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leading)

        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                cells.append(date)
            }
        }

        let trailing = (7 - cells.count % 7) % 7
        if trailing > 0, let last = cells.compactMap({ $0 }).last {
            for offset in 1...trailing {
                cells.append(calendar.date(byAdding: .day, value: offset, to: last))
            }
        }

        return cells
    }

    private func shiftMonth(by amount: Int) {
        if let new = calendar.date(byAdding: .month, value: amount, to: displayedMonth) {
            displayedMonth = new
        }
    }
}
