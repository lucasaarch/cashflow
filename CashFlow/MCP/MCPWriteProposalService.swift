import Foundation
import SwiftData

enum MCPWriteProposalOutcome: String, Codable {
    case pendingConfirmation = "pending_confirmation"
    case alreadyApplied = "already_applied"
    case cancelled = "cancelled"
}

struct MCPWriteProposalResponse: Codable {
    let status: MCPWriteProposalOutcome
    let action: String
    let summary: String
    let params: [String: AIToolJSONValue]
    let confirmationID: String

    enum CodingKeys: String, CodingKey {
        case status
        case action
        case summary
        case params
        case confirmationID = "confirmation_id"
    }
}

@MainActor
enum MCPWriteProposalService {
    private static let appliedKey = "mcp.writeProposals.applied"
    private static let cancelledKey = "mcp.writeProposals.cancelled"

    static func propose(name: String, arguments: [String: Any], container: ModelContainer) -> (text: String, isError: Bool) {
        guard let definition = AIToolCatalog.definition(named: name), definition.isWrite else {
            return ("Ferramenta '\(name)' não é uma ferramenta de escrita.", true)
        }

        do {
            let context = try AIToolContextFactory.make(from: container)
            let summary = try AIToolWriters.buildSummary(toolName: name, args: arguments, context: context)
            let confirmationID = UUID()
            let params = arguments.mapValues { AIToolJSONValue.from($0) }
            let argumentsJSON = encodeArguments(arguments)

            let pending = AIPendingWriteAction(
                id: confirmationID,
                toolCallID: confirmationID.uuidString,
                toolName: name,
                argumentsJSON: argumentsJSON,
                summary: summary,
                source: .mcp
            )

            MCPWriteProposalStore.shared.present(pending)
            MCPWriteProposalPersistence.save(pending, in: container.mainContext)

            let response = MCPWriteProposalResponse(
                status: .pendingConfirmation,
                action: name,
                summary: summary,
                params: params,
                confirmationID: confirmationID.uuidString
            )
            return encodeResponse(response, isError: false)
        } catch {
            return (error.localizedDescription, true)
        }
    }

    static func apply(_ pending: AIPendingWriteAction, container: ModelContainer) throws {
        guard appliedIDs().contains(pending.id.uuidString) == false else { return }

        let context = try AIToolContextFactory.make(from: container)
        let args = AIToolCall(id: pending.toolCallID, name: pending.toolName, argumentsJSON: pending.argumentsJSON).arguments
        let payload = try AIToolWriters.execute(toolName: pending.toolName, args: args, context: context)
        guard payload.ok else {
            throw AIToolExecutorError.invalidArguments(payload.error ?? "Não foi possível aplicar a ação.")
        }
        markApplied(pending.id, container: container)
        try context.modelContext.save()
    }

    static func markApplied(_ id: UUID, container: ModelContainer) {
        var applied = appliedIDs()
        applied.insert(id.uuidString)
        UserDefaults.standard.set(Array(applied), forKey: appliedKey)
        removePending(id, container: container)
    }

    static func markCancelled(_ id: UUID, container: ModelContainer) {
        var cancelled = cancelledIDs()
        cancelled.insert(id.uuidString)
        UserDefaults.standard.set(Array(cancelled), forKey: cancelledKey)
        removePending(id, container: container)
    }

    private static func removePending(_ id: UUID, container: ModelContainer) {
        MCPWriteProposalPersistence.remove(id, in: container.mainContext)
        if MCPWriteProposalStore.shared.pendingWrite?.id == id {
            MCPWriteProposalStore.shared.clear()
        }
    }

    private static func appliedIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: appliedKey) ?? [])
    }

    private static func cancelledIDs() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: cancelledKey) ?? [])
    }

    private static func encodeArguments(_ arguments: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(arguments),
              let data = try? JSONSerialization.data(withJSONObject: arguments, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private static func encodeResponse(_ response: MCPWriteProposalResponse, isError: Bool) -> (text: String, isError: Bool) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(response),
              let text = String(data: data, encoding: .utf8) else {
            return ("{\"status\":\"error\",\"error\":\"Failed to encode proposal\"}", true)
        }
        return (text, isError)
    }
}
