import Foundation

enum MCPAvailability {
    @MainActor
    static func ensureReadyForChat() throws {
        #if os(macOS)
        let coordinator = MCPServerCoordinator.shared
        guard MCPConfiguration.isSupportedPlatform else {
            throw AIError.providerError("As ferramentas do CashFlow via MCP só estão disponíveis no macOS.")
        }
        guard coordinator.isEnabled else {
            throw AIError.providerError(
                "O servidor MCP do CashFlow está desativado. Ative em Inteligência → Servidor MCP."
            )
        }
        guard coordinator.isRunning else {
            if let lastError = coordinator.lastError, !lastError.isEmpty {
                throw AIError.providerError(
                    "O servidor MCP do CashFlow não está rodando: \(lastError)"
                )
            }
            throw AIError.networkUnavailable(
                host: MCPConfiguration.host,
                port: Int(MCPConfiguration.port)
            )
        }
        #else
        throw AIError.providerError("As ferramentas do CashFlow via MCP só estão disponíveis no macOS.")
        #endif
    }
}
