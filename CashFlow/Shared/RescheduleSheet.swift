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
            formContent
            Divider()
            footer.cfAdaptiveSheetFooterVisible()
        }
        .cfAdaptiveSheetNavigation()
        .cfAdaptiveSheetFrame(width: 380, height: 300)
        .cfCompactSheetToolbar(
            title: title,
            saveTitle: "Salvar",
            saveDisabled: !hasChanges,
            onCancel: { dismiss() },
            onSave: { save(); dismiss() }
        )
        .cfAdaptiveSheetDetents()
        .cfGlassSheetChrome()
    }

    private var formContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    CFGlassSheetHero(
                        systemName: "calendar.badge.clock",
                        title: subtitle,
                        subtitle: "Data atual: \(initialDate.formatted(.dateTime.day().month(.wide).locale(Money.locale)))"
                    )

                    CFGlassFormPanel(title: "Nova data") {
                        CFGlassLabeledField(label: "Data") {
                            DateField(date: $date)
                        }
                    }

                    HStack(spacing: 8) {
                        quickShiftButton(label: "+1 dia", days: 1)
                        quickShiftButton(label: "+7 dias", days: 7)
                        quickShiftButton(label: "+15 dias", days: 15)
                        quickShiftButton(label: "+30 dias", days: 30)
                    }
                }
                .padding(20)
            }
        }
        .scrollIndicators(.never)
    }

    private func quickShiftButton(label: String, days: Int) -> some View {
        Button {
            if let shifted = Calendar.current.date(byAdding: .day, value: days, to: initialDate) {
                date = shifted
            }
        } label: {
            Text(label)
                .font(.caption.weight(.medium))
        }
        .cfGlassSecondaryButton()
    }

    private var footer: some View {
        CFGlassSheetFooter(
            confirmDisabled: !hasChanges,
            onCancel: { dismiss() },
            onConfirm: { save(); dismiss() }
        )
    }

    private func save() {
        onSave(date)
    }
}
