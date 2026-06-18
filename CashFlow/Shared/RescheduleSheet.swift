import SwiftUI

/// Small reusable sheet for shifting a single date forward/back without opening
/// the full edit flow. Used by Bills ("Reagendar vencimento") and Receivables
/// ("Reagendar recebível").
struct RescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let subtitle: String
    let initialDate: Date
    let onSave: (Date) -> Void

    @State private var date: Date

    init(title: String, subtitle: String, initialDate: Date, onSave: @escaping (Date) -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.initialDate = initialDate
        self.onSave = onSave
        _date = State(initialValue: initialDate)
    }

    private var hasChanges: Bool {
        Calendar.current.startOfDay(for: date) != Calendar.current.startOfDay(for: initialDate)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 380, height: 280)
        .cfCompactSheetToolbar(
            title: title,
            saveTitle: "Salvar",
            saveDisabled: !hasChanges,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfSheetBackground()
        .tint(CFTheme.accent)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(subtitle)
                .font(CFTheme.body())
                .foregroundStyle(CFTheme.textPrimary)
            Text("Data atual: \(initialDate.formatted(.dateTime.day().month(.wide).locale(Money.locale)))")
                .font(CFTheme.caption())
                .foregroundStyle(CFTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Nova data")
                    .font(CFTheme.body())
                    .foregroundStyle(CFTheme.textSecondary)
                Spacer(minLength: 8)
                DateField(date: $date)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(CFTheme.surfaceElevated.opacity(0.38))
            )

            HStack(spacing: 8) {
                quickShiftButton(label: "+1 dia", days: 1)
                quickShiftButton(label: "+7 dias", days: 7)
                quickShiftButton(label: "+15 dias", days: 15)
                quickShiftButton(label: "+30 dias", days: 30)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func quickShiftButton(label: String, days: Int) -> some View {
        Button {
            if let shifted = Calendar.current.date(byAdding: .day, value: days, to: initialDate) {
                date = shifted
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(CFTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(CFTheme.textTertiary.opacity(0.12)))
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            CFPillButton(title: "Cancelar", style: .ghost) { dismiss() }
                .keyboardShortcut(.cancelAction)
            CFPillButton(title: "Salvar", style: .primary) {
                save()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .opacity(hasChanges ? 1 : 0.5)
            .allowsHitTesting(hasChanges)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func save() {
        onSave(date)
    }
}
