import Foundation

final class AIConfiguration {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var activeProvider: AIProviderID? {
        get {
            guard let raw = defaults.string(forKey: UserDefaultsKeys.aiActiveProvider) else { return nil }
            return AIProviderID(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue, forKey: UserDefaultsKeys.aiActiveProvider) }
    }

    var activeModelID: String? {
        get { defaults.string(forKey: UserDefaultsKeys.aiActiveModelID) }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.aiActiveModelID) }
    }

    var ollamaHost: String {
        get { defaults.string(forKey: UserDefaultsKeys.aiOllamaHost) ?? "127.0.0.1" }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.aiOllamaHost) }
    }

    var ollamaPort: Int {
        get {
            let value = defaults.integer(forKey: UserDefaultsKeys.aiOllamaPort)
            return value == 0 ? 11434 : value
        }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.aiOllamaPort) }
    }

    var isReady: Bool {
        guard let provider = activeProvider, let model = activeModelID, !model.isEmpty else { return false }
        return isConfigured(provider)
    }

    func isConfigured(_ provider: AIProviderID) -> Bool {
        switch provider {
        case .openai: return SecureStore.read(.openAIAPIKey) != nil
        case .anthropic: return SecureStore.read(.anthropicAPIKey) != nil
        case .ollama: return !ollamaHost.isEmpty && ollamaPort > 0
        }
    }

    func ollamaBaseURL() -> URL? {
        URL(string: "http://\(ollamaHost):\(ollamaPort)")
    }
}
