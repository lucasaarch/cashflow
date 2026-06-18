import Foundation
import SwiftData

/// Singleton de preferências do app (uma linha, `id == "default"`).
/// Quando `CLOUDKIT_SYNC` estiver ativo, sincroniza via SwiftData + CloudKit.
@Model
final class AppSettings {
    @Attribute(.unique) var id: String

    init(id: String = AppSettingsBootstrap.defaultID) {
        self.id = id
    }
}
