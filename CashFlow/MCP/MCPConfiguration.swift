import Foundation

enum MCPConfiguration {
    static let host = "127.0.0.1"
    static let port: UInt16 = 8765
    static let endpointPath = "/mcp"
    static let serverURL = "http://\(host):\(port)\(endpointPath)"
    static let serverName = "cashflow"
    static let protocolVersion = "2024-11-05"

    static var isSupportedPlatform: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    static var isEnabledByDefault: Bool { true }

    static var cursorConfigSnippet: String {
        """
        {
          "mcpServers": {
            "\(serverName)": {
              "type": "http",
              "url": "\(serverURL)"
            }
          }
        }
        """
    }

    static let cursorConfigPath = "~/.cursor/mcp.json"
}
