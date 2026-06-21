import Foundation

struct CustomAIProvider: Sendable, Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var baseURL: String
    var supportsTools: Bool
    var didConnect: Bool

    init(
        id: UUID = UUID(),
        name: String,
        baseURL: String = "",
        supportsTools: Bool = true,
        didConnect: Bool = false
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.supportsTools = supportsTools
        self.didConnect = didConnect
    }

    nonisolated static var suggestedBaseURL: String {
        OpenAIBaseURLNormalizer.defaultCompatibleURL
    }

    nonisolated var resolvedBaseURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return OpenAIBaseURLNormalizer.normalize(trimmed)
    }

    nonisolated var isConfigured: Bool {
        resolvedBaseURL != nil && didConnect
    }
}
