import Foundation
import SwiftData

enum AppSettingsBootstrap {
    static let defaultID = "default"

    /// Garante a linha singleton de preferências do app.
    static func ensureExists(context: ModelContext) {
        let descriptor = FetchDescriptor<AppSettings>(
            predicate: #Predicate { $0.id == "default" }
        )

        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        context.insert(AppSettings())
        try? context.save()
    }
}
