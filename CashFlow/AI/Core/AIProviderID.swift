import Foundation

enum AIProviderID: String, CaseIterable, Codable, Hashable {
    case openai
    case anthropic
    case ollama

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .ollama: return "Local (Ollama)"
        }
    }

    var symbolName: String {
        switch self {
        case .openai: return "brain.head.profile"
        case .anthropic: return "sparkles"
        case .ollama: return "server.rack"
        }
    }
}
