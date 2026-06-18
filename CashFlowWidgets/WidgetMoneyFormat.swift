import Foundation

// Keep in sync with CashFlow/Shared/Widgets/WidgetMoneyFormat.swift

enum WidgetMoneyFormat {
    private static let locale = Locale(identifier: "pt_BR")

    static func brl(minorUnits: Int64, hidden: Bool) -> String {
        guard !hidden else { return "••••••" }
        return Decimal(minorUnits: minorUnits).brl.normalizedCurrencySpacing
    }

    static func compactBRL(minorUnits: Int64, hidden: Bool) -> String {
        guard !hidden else { return "•••" }
        let value = NSDecimalNumber(decimal: Decimal(minorUnits: minorUnits)).doubleValue
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        switch absValue {
        case 1_000_000...:
            return "\(sign)R$ \(String(format: "%.1fM", absValue / 1_000_000))"
        case 1_000...:
            return "\(sign)R$ \(String(format: "%.0fK", absValue / 1_000))"
        default:
            return brl(minorUnits: minorUnits, hidden: false)
        }
    }

    nonisolated static func dueLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: date)
        guard let diff = calendar.dateComponents([.day], from: today, to: target).day else {
            return absoluteDay(date)
        }
        switch diff {
        case 0: return "hoje"
        case 1: return "amanhã"
        case -1: return "ontem"
        default:
            return absoluteDay(date)
        }
    }

    nonisolated private static func absoluteDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "d/MMM"
        return formatter.string(from: date).replacingOccurrences(of: ".", with: "")
    }
}

private extension Decimal {
    var brl: String {
        formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
    }
}

private extension String {
    var normalizedCurrencySpacing: String {
        replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}
