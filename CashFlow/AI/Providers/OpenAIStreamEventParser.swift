import Foundation

/// Parses OpenAI-compatible SSE chunks, including non-standard `x_tool_call` events.
struct OpenAIStreamEventParser {
    private var activeCallIDsByTool: [String: [String]] = [:]

    mutating func parseSSELine(_ line: String) -> AIStreamChunk? {
        guard line.hasPrefix("data: ") else { return nil }
        let payload = String(line.dropFirst(6))
        guard payload != "[DONE]" else {
            return AIStreamChunk(isFinished: true)
        }

        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let toolCall = object["x_tool_call"] as? [String: Any],
           let name = toolCall["name"] as? String,
           let statusRaw = toolCall["status"] as? String,
           let status = AIStreamToolCallEvent.Status(rawValue: statusRaw) {
            let server = toolCall["server"] as? String
            if let server, !server.isEmpty, server != MCPConfiguration.serverName {
                return nil
            }

            let callID: String
            switch status {
            case .started:
                callID = UUID().uuidString.lowercased()
                activeCallIDsByTool[name, default: []].append(callID)
            case .completed:
                if activeCallIDsByTool[name]?.isEmpty == false {
                    callID = activeCallIDsByTool[name]!.removeFirst()
                } else {
                    callID = UUID().uuidString.lowercased()
                }
            }

            return AIStreamChunk(
                toolCallEvent: AIStreamToolCallEvent(
                    callID: callID,
                    name: name,
                    server: server,
                    status: status
                )
            )
        }

        if let choices = object["choices"] as? [[String: Any]],
           let first = choices.first,
           let delta = first["delta"] as? [String: Any],
           let content = delta["content"] as? String,
           !content.isEmpty {
            return AIStreamChunk(content: content)
        }

        return nil
    }
}
