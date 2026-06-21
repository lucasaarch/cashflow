import Foundation
import UserNotifications

@MainActor
enum WeeklyReminderNotifications {
    private static let identifier = "cashflow-weekly-gio-reminder"

    static func resync(
        bills: [Bill],
        receivables: [Receivable],
        enabled: Bool? = nil
    ) {
        let isEnabled = enabled ?? (UserDefaults.standard.object(forKey: UserDefaultsKeys.weeklyReminderEnabled) as? Bool ?? true)
        guard isEnabled else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        Task {
            await BillNotifications.ensureAuthorization()

            let calendar = Calendar.current
            let weekKey = weekIdentifier(for: .now, calendar: calendar)
            if UserDefaults.standard.string(forKey: UserDefaultsKeys.weeklyReminderLastScheduledWeek) == weekKey {
                return
            }

            let interval = calendar.dateInterval(of: .weekOfYear, for: .now)
            let pendingBills = bills.filter {
                guard $0.isPending, let interval else { return false }
                return interval.contains($0.dueDate)
            }
            let pendingReceivables = receivables.filter {
                guard $0.isPending, let interval else { return false }
                return interval.contains($0.expectedDate)
            }

            guard !pendingBills.isEmpty || !pendingReceivables.isEmpty else { return }

            let billsTotal = pendingBills.reduce(Decimal(0)) { $0 + $1.amount }
            let receivablesTotal = pendingReceivables.reduce(Decimal(0)) { $0 + $1.amount }

            var bodyParts: [String] = []
            if billsTotal > 0 {
                bodyParts.append("\(pendingBills.count) conta(s) a pagar (\(billsTotal.brl))")
            }
            if receivablesTotal > 0 {
                bodyParts.append("\(pendingReceivables.count) recebimento(s) (\(receivablesTotal.brl))")
            }

            var components = DateComponents()
            components.weekday = 2
            components.hour = 9
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "Resumo da semana — \(AIAssistantIdentity.name)"
            content.body = bodyParts.joined(separator: " · ")
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
            try? await UNUserNotificationCenter.current().add(request)
            UserDefaults.standard.set(weekKey, forKey: UserDefaultsKeys.weeklyReminderLastScheduledWeek)
        }
    }

    private static func weekIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }
}
