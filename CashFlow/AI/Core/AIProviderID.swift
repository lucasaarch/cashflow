import Foundation

enum AIProviderID: Sendable, Hashable, Identifiable, Codable {
    case openai
    case anthropic
    case custom(UUID)

    nonisolated var id: String { storageValue }

    nonisolated static var builtInAllCases: [AIProviderID] {
        [.openai, .anthropic]
    }

    nonisolated var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .custom: return "Provedor compatível"
        }
    }

    nonisolated var symbolName: String {
        switch self {
        case .openai: return "brain.head.profile"
        case .anthropic: return "sparkles"
        case .custom: return "server.rack"
        }
    }

    nonisolated var storageValue: String {
        switch self {
        case .openai: return "openai"
        case .anthropic: return "anthropic"
        case .custom(let id): return "custom:\(id.uuidString)"
        }
    }

    nonisolated init?(storageValue: String) {
        switch storageValue {
        case "openai":
            self = .openai
        case "anthropic":
            self = .anthropic
        default:
            guard storageValue.hasPrefix("custom:") else { return nil }
            let uuidString = String(storageValue.dropFirst("custom:".count))
            guard let uuid = UUID(uuidString: uuidString) else { return nil }
            self = .custom(uuid)
        }
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let value = AIProviderID(storageValue: raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unknown provider id: \(raw)")
        }
        self = value
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(storageValue)
    }

    nonisolated static func == (lhs: AIProviderID, rhs: AIProviderID) -> Bool {
        lhs.storageValue == rhs.storageValue
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(storageValue)
    }
}
