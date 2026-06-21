import Foundation

enum ConversationTitleFormatter {
    nonisolated static func make(from userMessage: String) -> String {
        let collapsed = userMessage
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return "Nova conversa" }

        let singleLine = collapsed.replacingOccurrences(of: "\n", with: " ")
        if singleLine.count <= 42 { return singleLine }
        let index = singleLine.index(singleLine.startIndex, offsetBy: 42)
        return String(singleLine[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}
