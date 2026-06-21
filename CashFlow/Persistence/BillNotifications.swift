import Foundation
import UserNotifications

/// Local notification scheduler for Bill due dates. Fires once on the morning
/// of the due date (9:00 local). Idempotent — re-scheduling replaces the previous request.
@MainActor
enum BillNotifications {
    private static var didRequestAuthorization = false

    static func ensureAuthorization() async {
        guard !didRequestAuthorization else { return }
        didRequestAuthorization = true
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    static func schedule(for bill: Bill) {
        guard bill.isPending else { return }
        Task {
            await ensureAuthorization()

            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: bill.dueDate)
            components.hour = 9
            components.minute = 0

            guard let fireDate = calendar.date(from: components), fireDate > .now else {
                cancel(for: bill)
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Conta vence hoje"
            content.body = "\(bill.name) — \(bill.amount.brl)"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: identifier(for: bill),
                content: content,
                trigger: trigger
            )

            // Replace any previous schedule for the same bill (e.g. dueDate changed).
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: [request.identifier])
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    static func cancel(for bill: Bill) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier(for: bill)])
    }

    static func resync(pending bills: [Bill]) {
        for bill in bills where bill.isPending {
            schedule(for: bill)
        }
    }

    private static func identifier(for bill: Bill) -> String {
        "bill-due-\(bill.id.uuidString)"
    }
}
