import Foundation
import SwiftData

enum AppSettingsBootstrap {
    static let defaultID = "default"

    /// Garante a linha singleton e migra `monthlyIncomeCents` legado do UserDefaults uma vez.
    static func ensureExists(context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>(
            predicate: #Predicate { $0.id == "default" }
        )

        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let legacyCents = UserDefaults.standard.integer(forKey: UserDefaultsKeys.monthlyIncomeCents)
        context.insert(AppSettings(monthlyIncomeCents: legacyCents))
        try? context.save()
    }
}
