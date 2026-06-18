import Foundation

struct AIToolExecutionOutcome {
    let resultJSON: String
    let pendingWrite: AIPendingWriteAction?
}

enum AIToolExecutorError: LocalizedError {
    case unknownTool(String)
    case invalidArguments(String)

    var errorDescription: String? {
        switch self {
        case .unknownTool(let name):
            return "Ferramenta desconhecida: \(name)."
        case .invalidArguments(let message):
            return message
        }
    }
}

@MainActor
struct AIToolExecutor {
    let context: AIToolContext

    func execute(call: AIToolCall, confirmed: Bool = false) -> AIToolExecutionOutcome {
        let definition = AIToolCatalog.definition(named: call.name)
        guard let definition else {
            return AIToolExecutionOutcome(
                resultJSON: AIToolJSON.encodeString(.failure("Ferramenta '\(call.name)' não existe.")),
                pendingWrite: nil
            )
        }

        if definition.isWrite, !confirmed {
            do {
                let summary = try AIToolWriters.buildSummary(toolName: call.name, args: call.arguments, context: context)
                let action = AIPendingWriteAction(
                    id: UUID(),
                    toolCallID: call.id,
                    toolName: call.name,
                    argumentsJSON: call.argumentsJSON,
                    summary: summary
                )
                return AIToolExecutionOutcome(
                    resultJSON: AIToolJSON.encodeString(.pending(summary: summary, actionID: action.id)),
                    pendingWrite: action
                )
            } catch {
                return AIToolExecutionOutcome(
                    resultJSON: AIToolJSON.encodeString(.failure(error.localizedDescription)),
                    pendingWrite: nil
                )
            }
        }

        do {
            let payload: AIToolResultPayload
            if definition.isWrite {
                payload = try AIToolWriters.execute(toolName: call.name, args: call.arguments, context: context)
            } else {
                payload = try AIToolReaders.execute(name: call.name, args: call.arguments, context: context)
            }
            return AIToolExecutionOutcome(resultJSON: AIToolJSON.encodeString(payload), pendingWrite: nil)
        } catch {
            return AIToolExecutionOutcome(
                resultJSON: AIToolJSON.encodeString(.failure(error.localizedDescription)),
                pendingWrite: nil
            )
        }
    }
}
