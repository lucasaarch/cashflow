import SwiftUI

struct DateField: View {
    @Binding var date: Date
    @State private var showingPopover = false

    var body: some View {
        Button {
            showingPopover = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(CFTheme.brandGreen)
                Text(displayString)
                    .foregroundStyle(CFTheme.textPrimary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(CFTheme.textTertiary.opacity(0.12))
        )
        .popover(isPresented: $showingPopover, arrowEdge: .top) {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    quickChip("Hoje", date: .now)
                    quickChip("Ontem", date: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now)
                }
                .padding(.horizontal, 14)
                .padding(.top, 14)

                DatePicker("", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
            .frame(minWidth: 280)
        }
    }

    private var displayString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoje" }
        if calendar.isDateInYesterday(date) { return "Ontem" }
        return date.formatted(.dateTime.day().month(.wide).locale(Money.locale))
    }

    private func quickChip(_ label: String, date target: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: target)
        return Button {
            date = target
            showingPopover = false
        } label: {
            Text(label)
                .font(.callout)
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? CFTheme.brandGreen.opacity(0.22) : CFTheme.textTertiary.opacity(0.12))
                )
                .foregroundStyle(isSelected ? CFTheme.brandGreen : CFTheme.textPrimary)
        }
        .buttonStyle(.plain)
    }
}
