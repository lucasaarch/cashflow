import Foundation

enum DataReset {
    /// Bump this token whenever you need to force-wipe local data on next launch.
    /// Each unique token runs exactly once.
    private static let wipeToken = "fresh_start_2026_06_17_ai"
    private static let lastAppliedKey = "lastAppliedWipeToken"

    /// Must run BEFORE creating the ModelContainer — deletes the SwiftData store files
    /// from disk so that any schema change (new fields, removed types) won't crash on load.
    static func wipeStoreIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.string(forKey: lastAppliedKey) != wipeToken else { return }

        deleteDefaultStore()

        defaults.set(wipeToken, forKey: lastAppliedKey)
        defaults.removeObject(forKey: UserDefaultsKeys.hasSeededDefaults)
        defaults.removeObject(forKey: UserDefaultsKeys.lastUsedAccountID)
        defaults.removeObject(forKey: UserDefaultsKeys.lastUsedCategoryID)
        defaults.removeObject(forKey: UserDefaultsKeys.aiActiveProvider)
        defaults.removeObject(forKey: UserDefaultsKeys.aiActiveModelID)
        defaults.removeObject(forKey: UserDefaultsKeys.aiOllamaHost)
        defaults.removeObject(forKey: UserDefaultsKeys.aiOllamaPort)
        SecureStore.delete(.openAIAPIKey)
        SecureStore.delete(.anthropicAPIKey)
    }

    private static func deleteDefaultStore() {
        let fm = FileManager.default
        guard let baseDir = try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        ) else { return }

        let baseStore = baseDir.appendingPathComponent("default.store")
        // SwiftData uses SQLite — remove the main file plus its journal companions.
        for suffix in ["", "-shm", "-wal"] {
            let url = URL(fileURLWithPath: baseStore.path + suffix)
            try? fm.removeItem(at: url)
        }
    }
}
