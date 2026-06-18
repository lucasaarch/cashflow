import Foundation

enum AIProviderID: String, CaseIterable, Codable, Hashable, Identifiable {
    var id: Self { self }
    case openai
    case anthropic

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }

    var symbolName: String {
        switch self {
        case .openai: return "brain.head.profile"
        case .anthropic: return "sparkles"
        }
    }
}
