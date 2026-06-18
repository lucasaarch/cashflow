import Foundation

/// Persona da assistente de IA do CashFlow — usada na UI e nos prompts.
enum AIAssistantIdentity {
    static let name = "Gio"
    static let subtitle = "Conversa sobre suas finanças"

    static var systemIntroduction: String {
        "Você é \(name), o analista financeiro do CashFlow."
    }
}
