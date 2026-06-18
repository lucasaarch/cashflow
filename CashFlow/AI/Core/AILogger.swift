import Foundation
import os

/// Centralized logging for the AI stack. Filter in Console.app or Xcode by
/// subsystem `com.cashflow.ai` and the desired category.
enum AILogger {
    static let subsystem = "com.cashflow.ai"

    static let http = Logger(subsystem: subsystem, category: "http")
    static let agent = Logger(subsystem: subsystem, category: "agent")
    static let tools = Logger(subsystem: subsystem, category: "tools")
    static let provider = Logger(subsystem: subsystem, category: "provider")
}
