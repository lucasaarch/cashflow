import Foundation

final class AIConfiguration {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var activeProvider: AIProviderID? {
        get {
            guard let raw = defaults.string(forKey: UserDefaultsKeys.aiActiveProvider) else { return nil }
            guard let provider = AIProviderID(rawValue: raw) else {
                defaults.removeObject(forKey: UserDefaultsKeys.aiActiveProvider)
                return nil
            }
            return provider
        }
        set { defaults.set(newValue?.rawValue, forKey: UserDefaultsKeys.aiActiveProvider) }
    }

    var activeModelID: String? {
        get {
            guard let raw = defaults.string(forKey: UserDefaultsKeys.aiActiveModelID) else { return nil }
            let migrated: String
            if activeProvider == .anthropic {
                migrated = AnthropicModelCatalog.migrate(modelID: raw)
            } else {
                migrated = raw
            }
            if migrated != raw {
                defaults.set(migrated, forKey: UserDefaultsKeys.aiActiveModelID)
            }
            return migrated
        }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.aiActiveModelID) }
    }

    var isReady: Bool {
        guard let provider = activeProvider, let model = activeModelID, !model.isEmpty else { return false }
        return isConfigured(provider)
    }

    func isConfigured(_ provider: AIProviderID) -> Bool {
        switch provider {
        case .openai: return SecureStore.read(.openAIAPIKey) != nil
        case .anthropic: return SecureStore.read(.anthropicAPIKey) != nil
        }
    }
}
