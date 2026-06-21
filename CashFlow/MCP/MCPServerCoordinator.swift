import Foundation
import SwiftData
import Combine
import os

@MainActor
final class MCPServerCoordinator: ObservableObject {
    static let shared = MCPServerCoordinator()

    @Published private(set) var isRunning = false
    @Published private(set) var lastError: String?

    private var container: ModelContainer?
    private var httpServer: MCPHTTPServer?
    private var requestHandler: MCPRequestHandler?

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: UserDefaultsKeys.mcpServerEnabled) == nil {
                return MCPConfiguration.isEnabledByDefault
            }
            return UserDefaults.standard.bool(forKey: UserDefaultsKeys.mcpServerEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.mcpServerEnabled)
            MCPLogger.server.info("MCP server \(newValue ? "enabled" : "disabled", privacy: .public)")
            if newValue {
                start()
            } else {
                stop()
            }
        }
    }

    private init() {}

    func configure(container: ModelContainer) {
        self.container = container
        MCPLogger.server.info("Configured with SwiftData container")
        guard isEnabled else {
            MCPLogger.server.debug("Server disabled; skipping start")
            return
        }
        guard !isRunning else {
            MCPLogger.server.debug("MCP server already running; skipping configure start")
            return
        }
        start()
    }

    func start() {
        #if os(macOS)
        guard MCPConfiguration.isSupportedPlatform else {
            MCPLogger.server.debug("Unsupported platform; MCP server not started")
            return
        }
        guard let container else {
            lastError = "Container SwiftData indisponível."
            MCPLogger.server.error("Start failed: SwiftData container unavailable")
            return
        }

        guard !isRunning else {
            MCPLogger.server.debug("MCP server already running; skipping start")
            return
        }

        MCPLogger.server.info("Starting MCP server at \(MCPConfiguration.serverURL, privacy: .public)")

        let handler = MCPRequestHandler(container: container)
        requestHandler = handler
        let server = MCPHTTPServer()
        handler.onCloseSession = { sessionID in
            server.closeSSEStream(sessionID: sessionID)
        }

        do {
            try server.start { [handler] request in
                handler.handle(request)
            }
            httpServer = server
            isRunning = true
            lastError = nil
            MCPLogger.server.info("MCP server running on \(MCPConfiguration.host, privacy: .public):\(MCPConfiguration.port) readTools=\(AIToolCatalog.readTools.count)")
        } catch {
            httpServer = nil
            requestHandler = nil
            isRunning = false
            lastError = error.localizedDescription
            MCPLogger.server.error("Start failed: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }

    func stop() {
        guard httpServer != nil else { return }
        MCPLogger.server.info("Stopping MCP server")
        httpServer?.stop()
        httpServer = nil
        requestHandler = nil
        isRunning = false
    }

    func restart() {
        #if os(macOS)
        guard isEnabled else {
            MCPLogger.server.debug("Restart ignored: MCP server disabled")
            return
        }
        MCPLogger.server.info("Restarting MCP server")
        stop()
        start()
        #endif
    }

    var statusSummary: String {
        guard isEnabled else { return "Desativado" }
        if isRunning { return "Ativo" }
        if let lastError, !lastError.isEmpty { return "Falha" }
        return "Parado"
    }

    var statusDetail: String? {
        guard isEnabled else {
            return "Ative para expor as ferramentas do CashFlow em \(MCPConfiguration.serverURL)."
        }
        if isRunning {
            return "\(MCPConfiguration.serverURL) · \(AIToolCatalog.mcpTools.count) ferramentas (\(AIToolCatalog.writeTools.count) propostas de escrita)"
        }
        if let lastError, !lastError.isEmpty {
            return lastError
        }
        return "O servidor deveria estar ativo, mas não está escutando. Tente reiniciar."
    }

    func copyConfigToPasteboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(MCPConfiguration.cursorConfigSnippet, forType: .string)
        #endif
    }
}

#if os(macOS)
import AppKit
#endif
