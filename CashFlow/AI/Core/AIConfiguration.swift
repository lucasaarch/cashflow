import Foundation

final class AIConfiguration {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateLegacyCustomProviderIfNeeded()
        normalizePersistedStateIfNeeded()
    }

    var activeProvider: AIProviderID? {
        get { resolveActiveProvider(from: storedActiveProviderRawValue) }
        set { defaults.set(newValue?.storageValue, forKey: UserDefaultsKeys.aiActiveProvider) }
    }

    var activeModelID: String? {
        get {
            guard let raw = defaults.string(forKey: UserDefaultsKeys.aiActiveModelID) else { return nil }
            if resolveActiveProvider(from: storedActiveProviderRawValue) == .anthropic {
                return AnthropicModelCatalog.migrate(modelID: raw)
            }
            return raw
        }
        set { defaults.set(newValue, forKey: UserDefaultsKeys.aiActiveModelID) }
    }

    var customProviders: [CustomAIProvider] {
        get {
            guard let data = defaults.data(forKey: UserDefaultsKeys.aiCustomProviders) else { return [] }
            return (try? JSONDecoder().decode([CustomAIProvider].self, from: data)) ?? []
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: UserDefaultsKeys.aiCustomProviders)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: UserDefaultsKeys.aiCustomProviders)
            }
        }
    }

    var isReady: Bool {
        guard let provider = activeProvider, let model = activeModelID, !model.isEmpty else { return false }
        return isConfigured(provider)
    }

    func configuredProviders() -> [AIProviderID] {
        var providers = AIProviderID.builtInAllCases.filter { isConfigured($0) }
        providers.append(contentsOf: customProviders.filter(\.isConfigured).map { .custom($0.id) })
        return providers
    }

    func displayName(for provider: AIProviderID) -> String {
        switch provider {
        case .openai, .anthropic:
            return provider.displayName
        case .custom(let id):
            return customProvider(id: id)?.name ?? provider.displayName
        }
    }

    func customProvider(id: UUID) -> CustomAIProvider? {
        customProviders.first { $0.id == id }
    }

    func upsertCustomProvider(_ provider: CustomAIProvider) {
        var providers = customProviders
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            let previous = providers[index]
            var updated = provider
            if previous.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                != provider.baseURL.trimmingCharacters(in: .whitespacesAndNewlines) {
                updated.didConnect = false
            }
            providers[index] = updated
        } else {
            providers.append(provider)
        }
        customProviders = providers
    }

    func deleteCustomProvider(id: UUID) {
        customProviders.removeAll { $0.id == id }
        SecureStore.deleteCustomProviderAPIKey(id)
        if activeProvider == .custom(id) {
            activeProvider = nil
            activeModelID = nil
        }
    }

    func markCustomProviderConnected(id: UUID) {
        guard var provider = customProvider(id: id), provider.resolvedBaseURL != nil else { return }
        provider.didConnect = true
        upsertCustomProvider(provider)
    }

    // MARK: - Favorite models

    func favoriteModelIDs(for provider: AIProviderID) -> [String] {
        favoriteModelsByProvider[provider.storageValue] ?? []
    }

    func isFavoriteModel(_ modelID: String, for provider: AIProviderID) -> Bool {
        favoriteModelIDs(for: provider).contains(modelID)
    }

    func toggleFavoriteModel(_ modelID: String, for provider: AIProviderID) {
        var map = favoriteModelsByProvider
        var favorites = map[provider.storageValue] ?? []
        if let index = favorites.firstIndex(of: modelID) {
            favorites.remove(at: index)
        } else {
            favorites.insert(modelID, at: 0)
            if favorites.count > 8 {
                favorites = Array(favorites.prefix(8))
            }
        }
        if favorites.isEmpty {
            map.removeValue(forKey: provider.storageValue)
        } else {
            map[provider.storageValue] = favorites
        }
        favoriteModelsByProvider = map
    }

    func sortedModels(_ models: [AIModel], for provider: AIProviderID) -> [AIModel] {
        let favorites = Set(favoriteModelIDs(for: provider))
        guard !favorites.isEmpty else {
            return models.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
        let favoriteModels = favoriteModelIDs(for: provider).compactMap { id in models.first { $0.id == id } }
        let remaining = models
            .filter { !favorites.contains($0.id) }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        return favoriteModels + remaining
    }

    func isConfigured(_ provider: AIProviderID) -> Bool {
        switch provider {
        case .openai:
            return SecureStore.read(.openAIAPIKey) != nil
        case .anthropic:
            return SecureStore.read(.anthropicAPIKey) != nil
        case .custom(let id):
            return customProvider(id: id)?.isConfigured == true
        }
    }

    /// Persists one-time migrations and removes stale keys. Safe to call at startup, not during view rendering.
    func normalizePersistedStateIfNeeded() {
        if let raw = storedActiveProviderRawValue {
            if raw == "local" || raw == "openAICompatible", let first = customProviders.first {
                defaults.set(AIProviderID.custom(first.id).storageValue, forKey: UserDefaultsKeys.aiActiveProvider)
            } else if let provider = AIProviderID(storageValue: raw) {
                if case .custom(let id) = provider, customProvider(id: id) == nil {
                    defaults.removeObject(forKey: UserDefaultsKeys.aiActiveProvider)
                }
            } else {
                defaults.removeObject(forKey: UserDefaultsKeys.aiActiveProvider)
            }
        }

        if let raw = defaults.string(forKey: UserDefaultsKeys.aiActiveModelID),
           resolveActiveProvider(from: storedActiveProviderRawValue) == .anthropic {
            let migrated = AnthropicModelCatalog.migrate(modelID: raw)
            if migrated != raw {
                defaults.set(migrated, forKey: UserDefaultsKeys.aiActiveModelID)
            }
        }
    }

    // MARK: - Legacy migration

    private var storedActiveProviderRawValue: String? {
        defaults.string(forKey: UserDefaultsKeys.aiActiveProvider)
    }

    private func resolveActiveProvider(from raw: String?) -> AIProviderID? {
        guard let raw else { return nil }
        if raw == "local" || raw == "openAICompatible" {
            return customProviders.first.map { .custom($0.id) }
        }
        guard let provider = AIProviderID(storageValue: raw) else { return nil }
        if case .custom(let id) = provider, customProvider(id: id) == nil {
            return nil
        }
        return provider
    }

    private func migrateLegacyCustomProviderIfNeeded() {
        guard defaults.data(forKey: UserDefaultsKeys.aiCustomProviders) == nil else { return }

        let legacyURL = defaults.string(forKey: UserDefaultsKeys.aiOpenAICompatibleBaseURL)
        let legacyDidConnect = defaults.bool(forKey: UserDefaultsKeys.aiOpenAICompatibleDidConnect)
        let hasLegacyConfig = legacyURL != nil || legacyDidConnect

        guard hasLegacyConfig else { return }

        let provider = CustomAIProvider(
            name: "OpenAI Compatible",
            baseURL: legacyURL ?? CustomAIProvider.suggestedBaseURL,
            supportsTools: legacySupportsTools(),
            didConnect: legacyDidConnect
        )
        customProviders = [provider]

        if let legacyKey = SecureStore.read(.openAICompatibleAPIKey) {
            try? SecureStore.saveCustomProviderAPIKey(legacyKey, providerID: provider.id)
        }

        defaults.removeObject(forKey: UserDefaultsKeys.aiOpenAICompatibleBaseURL)
        defaults.removeObject(forKey: UserDefaultsKeys.aiOpenAICompatibleSupportsTools)
        defaults.removeObject(forKey: UserDefaultsKeys.aiOpenAICompatibleDidConnect)

        if let raw = storedActiveProviderRawValue,
           raw == "local" || raw == "openAICompatible" {
            defaults.set(AIProviderID.custom(provider.id).storageValue, forKey: UserDefaultsKeys.aiActiveProvider)
        }
    }

    private func legacySupportsTools() -> Bool {
        if defaults.object(forKey: UserDefaultsKeys.aiOpenAICompatibleSupportsTools) == nil {
            return true
        }
        return defaults.bool(forKey: UserDefaultsKeys.aiOpenAICompatibleSupportsTools)
    }

    private var favoriteModelsByProvider: [String: [String]] {
        get {
            guard let data = defaults.data(forKey: UserDefaultsKeys.aiFavoriteModels) else { return [:] }
            return (try? JSONDecoder().decode([String: [String]].self, from: data)) ?? [:]
        }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: UserDefaultsKeys.aiFavoriteModels)
            } else if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: UserDefaultsKeys.aiFavoriteModels)
            }
        }
    }
}
