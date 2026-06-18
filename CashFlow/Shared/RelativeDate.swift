import Foundation

extension Date {
    /// Short pt_BR day-distance phrase. Returns nil when |distance| > maxDays so
    /// the caller falls back to an absolute date.
    ///
    /// Examples: "hoje", "amanhã", "ontem", "em 3 dias", "há 5 dias".
    func cfRelativeDay(now: Date = .now, calendar: Calendar = .current, maxDays: Int = 7) -> String? {
        let day = calendar.startOfDay(for: self)
        let today = calendar.startOfDay(for: now)
        guard let diff = calendar.dateComponents([.day], from: today, to: day).day else { return nil }
        guard abs(diff) <= maxDays else { return nil }
        switch diff {
        case 0: return "hoje"
        case 1: return "amanhã"
        case -1: return "ontem"
        case 2...: return "em \(diff) dias"
        default: return "há \(-diff) dias"
        }
    }

    /// Returns a relative phrase ("hoje", "em 3 dias") or, when out of range,
    /// the absolute date prefixed with "em" so it composes naturally after a
    /// verb: "Vence " + cfRelativeOrAbsoluteDay() → "Vence hoje" / "Vence em 17 de jun".
    func cfRelativeOrAbsoluteDay(now: Date = .now, calendar: Calendar = .current, maxDays: Int = 7) -> String {
        if let relative = cfRelativeDay(now: now, calendar: calendar, maxDays: maxDays) {
            return relative
        }
        let formatter = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(Money.locale)
        return "em \(formatted(formatter))"
    }
}
