import Foundation
import os

/// MCP server logging. Filter in Console.app or Xcode by subsystem `com.cashflow.mcp`.
enum MCPLogger {
    static let subsystem = "com.cashflow.mcp"

    static let server = Logger(subsystem: subsystem, category: "server")
    static let http = Logger(subsystem: subsystem, category: "http")
    static let rpc = Logger(subsystem: subsystem, category: "rpc")
    static let tools = Logger(subsystem: subsystem, category: "tools")
}
