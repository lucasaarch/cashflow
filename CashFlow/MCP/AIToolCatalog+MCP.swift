import Foundation

extension AIToolDefinition {
    static let mcpWriteConfirmationSuffix = " Apenas cria uma proposta; requer confirmação do usuário no app antes de efetivar."

    var mcpDescription: String {
        isWrite ? description + Self.mcpWriteConfirmationSuffix : description
    }

    /// MCP `tools/list` payload. Write tools are proposal-only via MCP (no mutation until app confirm),
    /// so they carry `readOnlyHint: true` for clients that block mutating tools in ask mode.
    var mcpToolListEntry: [String: Any] {
        var entry: [String: Any] = [
            "name": name,
            "description": mcpDescription,
            "inputSchema": MCPJSONSchema.build(from: self)
        ]
        if isWrite {
            entry["annotations"] = mcpWriteAnnotations
        }
        return entry
    }

    private var mcpWriteAnnotations: [String: Any] {
        ["readOnlyHint": true]
    }
}

extension AIToolCatalog {
    static var mcpTools: [AIToolDefinition] { all }
}
