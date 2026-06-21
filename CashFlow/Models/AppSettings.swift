import Foundation
import SwiftData

/// Singleton de preferências do app (uma linha, `id == "default"`).
/// Quando `CLOUDKIT_SYNC` estiver ativo, sincroniza via SwiftData + CloudKit.
@Model
final class AppSettings {
    @Attribute(.unique) var id: String

    var monthlyBudgetMinorUnits: Int64?

    init(id: String = AppSettingsBootstrap.defaultID, monthlyBudgetMinorUnits: Int64? = nil) {
        self.id = id
        self.monthlyBudgetMinorUnits = monthlyBudgetMinorUnits
    }

    var monthlyBudget: Decimal? {
        get {
            guard let monthlyBudgetMinorUnits else { return nil }
            return Decimal(monthlyBudgetMinorUnits) / 100
        }
        set {
            if let newValue {
                monthlyBudgetMinorUnits = newValue.minorUnits
            } else {
                monthlyBudgetMinorUnits = nil
            }
        }
    }
}
