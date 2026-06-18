import Foundation
import UserNotifications

/// Local notification scheduler for Receivable expected dates. Fires once on the morning
/// of the expected date (9:00 local) to remind the user to confirm the receipt manually.
/// Idempotent — re-scheduling replaces the previous request.
@MainActor
enum ReceivableNotifications {
    private static var didRequestAuthorization = false

    static func ensureAuthorization() async {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func schedule(for receivable: Receivable) {
        guard receivable.isPending else { return }
        Task {
            await ensureAuthorization()

            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: receivable.expectedDate)
            components.hour = 9
            components.minute = 0

            guard let fireDate = calendar.date(from: components), fireDate > .now else {
                cancel(for: receivable)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Recebimento esperado hoje"
            content.body = "\(receivable.name) — \(receivable.amount.brl)"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier(for: receivable),
                content: content,
                trigger: trigger
            )

            // Replace any previous schedule for the same receivable (e.g. expectedDate changed).
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [request.identifier])
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancel(for receivable: Receivable) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: receivable)])
    }

    private static func identifier(for receivable: Receivable) -> String {
        "receivable-due-\(receivable.id.uuidString)"
    }
}
