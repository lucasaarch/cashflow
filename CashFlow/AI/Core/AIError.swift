import Foundation

enum AIError: Error, Sendable, LocalizedError, Equatable {
    case noActiveProvider
    case notConfigured(AIProviderID)
    case invalidCredentials
    case networkUnavailable(host: String, port: Int)
    case modelNotFound(String)
    case providerError(String)
    case decodingFailed

    nonisolated var errorDescription: String? {
        switch self {
        case .noActiveProvider:
            return "Nenhum provedor de IA está ativo. Configure em Inteligência."
        case .notConfigured(let id):
            return "\(id.displayName) não está configurado."
        case .invalidCredentials:
            return "Credenciais inválidas. Verifique sua chave de API."
        case .networkUnavailable(let host, let port):
            return "Não foi possível conectar em \(host):\(port). Verifique se o serviço está rodando."
        case .modelNotFound(let model):
            return "Modelo não encontrado: \(model)."
        case .providerError(let message):
            return message
        case .decodingFailed:
            return "Resposta inválida do provedor de IA."
        }
    }

    nonisolated static func == (lhs: AIError, rhs: AIError) -> Bool {
        switch (lhs, rhs) {
        case (.noActiveProvider, .noActiveProvider):
            return true
        case (.notConfigured(let lhsID), .notConfigured(let rhsID)):
            return lhsID == rhsID
        case (.invalidCredentials, .invalidCredentials):
            return true
        case (.networkUnavailable(let lhsHost, let lhsPort), .networkUnavailable(let rhsHost, let rhsPort)):
            return lhsHost == rhsHost && lhsPort == rhsPort
        case (.modelNotFound(let lhsModel), .modelNotFound(let rhsModel)):
            return lhsModel == rhsModel
        case (.providerError(let lhsMessage), .providerError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.decodingFailed, .decodingFailed):
            return true
        default:
            return false
        }
    }
}
