import Foundation
import SwiftData

/// Singleton de preferências do app (uma linha, `id == "default"`).
/// Quando `CLOUDKIT_SYNC` estiver ativo, sincroniza via SwiftData + CloudKit.
@Model
final class AppSettings {
    @Attribute(.unique) var id: String
    var monthlyIncomeCents: Int

    init(id: String = AppSettingsBootstrap.defaultID, monthlyIncomeCents: Int = 0) {
        self.id = id
        self.monthlyIncomeCents = monthlyIncomeCents
    }
}
