import Foundation

/// Persona da assistente de IA do CashFlow — usada na UI e nos prompts.
enum AIAssistantIdentity {
    static let name = "Gio"
    static let subtitle = "Conversa sobre suas finanças"
    /// Toolbar / chat — distinto do ícone `plus` de criar registros.
    static let toolbarSymbolName = "bubble.left.and.bubble.right.fill"
    /// Configurações e sidebar de inteligência.
    static let settingsSymbolName = "sparkles"

    static var systemIntroduction: String {
        "Você é \(name), assistente do CashFlow — especialista em finanças pessoais do usuário, mas conversa de forma natural e flexível."
    }
}
