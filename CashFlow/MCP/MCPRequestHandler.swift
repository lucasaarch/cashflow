import Foundation
import SwiftData
import os

struct MCPHTTPRequest {
    let method: String
    let path: String
    let headers: [String: String]
    let body: Data
}

struct MCPHTTPResponse {
    var statusCode: Int
    var headers: [String: String]
    var body: Data
    /// When true, the HTTP server keeps the TCP connection open (SSE stream).
    var keepsConnectionOpen: Bool = false
    /// Session to associate with a persistent SSE connection.
    var sseSessionID: String?

    init(
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data(),
        keepsConnectionOpen: Bool = false,
        sseSessionID: String? = nil
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
        self.keepsConnectionOpen = keepsConnectionOpen
        self.sseSessionID = sseSessionID
    }

    static func json(_ object: Any, statusCode: Int = 200, extraHeaders: [String: String] = [:]) -> MCPHTTPResponse {
        var response = MCPHTTPResponse()
        response.statusCode = statusCode
        response.headers = [
            "Content-Type": "application/json",
            "Connection": "close"
        ].merging(extraHeaders) { _, new in new }

        if JSONSerialization.isValidJSONObject(object),
           let data = try? JSONSerialization.data(withJSONObject: object, options: []) {
            response.body = data
        } else {
            response.statusCode = 500
            response.body = Data("{\"error\":\"Failed to encode JSON\"}".utf8)
        }
        response.headers["Content-Length"] = String(response.body.count)
        return response
    }

    static func accepted(extraHeaders: [String: String] = [:]) -> MCPHTTPResponse {
        var headers = ["Connection": "close", "Content-Length": "0"]
        extraHeaders.forEach { headers[$0.key] = $0.value }
        return MCPHTTPResponse(statusCode: 202, headers: headers)
    }

    static func text(_ text: String, statusCode: Int = 200) -> MCPHTTPResponse {
        let body = Data(text.utf8)
        return MCPHTTPResponse(
            statusCode: statusCode,
            headers: [
                "Content-Type": "text/plain; charset=utf-8",
                "Connection": "close",
                "Content-Length": String(body.count)
            ],
            body: body
        )
    }

    static func sseStream(extraHeaders: [String: String] = [:], sessionID: String) -> MCPHTTPResponse {
        MCPHTTPResponse(
            statusCode: 200,
            headers: [
                "Content-Type": "text/event-stream",
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"
            ].merging(extraHeaders) { _, new in new },
            keepsConnectionOpen: true,
            sseSessionID: sessionID
        )
    }
}

enum MCPJSONRPC {
    static func success(id: Any?, result: Any) -> [String: Any] {
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "result": result
        ]
        if let id { payload["id"] = id }
        return payload
    }

    static func error(id: Any?, code: Int, message: String) -> [String: Any] {
        var payload: [String: Any] = [
            "jsonrpc": "2.0",
            "error": [
                "code": code,
                "message": message
            ]
        ]
        if let id { payload["id"] = id }
        return payload
    }
}

@MainActor
final class MCPRequestHandler {
    private let container: ModelContainer
    private var sessions: Set<String> = []
    private var isInitialized = false
    var onCloseSession: ((String) -> Void)?

    init(container: ModelContainer) {
        self.container = container
    }

    func handle(_ request: MCPHTTPRequest) -> MCPHTTPResponse {
        if request.method == "DELETE", request.path == MCPConfiguration.endpointPath {
            MCPLogger.rpc.debug("DELETE session")
            return handleDelete(sessionID: request.headers["mcp-session-id"])
        }

        if request.method == "GET", request.path == MCPConfiguration.endpointPath {
            return handleSSEGet(request)
        }

        guard request.method == "POST", request.path == MCPConfiguration.endpointPath else {
            MCPLogger.http.debug("Unhandled route: \(request.method, privacy: .public) \(request.path, privacy: .public)")
            if request.path == MCPConfiguration.endpointPath {
                return MCPHTTPResponse(statusCode: 405, headers: ["Connection": "close", "Content-Length": "0"])
            }
            return MCPHTTPResponse.text("Not Found", statusCode: 404)
        }

        guard acceptsMCP(request.headers) else {
            MCPLogger.http.error("Rejected request: unsupported Accept header")
            return MCPHTTPResponse.text("Not Acceptable", statusCode: 406)
        }

        guard let object = try? JSONSerialization.jsonObject(with: request.body) as? [String: Any] else {
            MCPLogger.rpc.error("JSON parse error body=\(request.body.count)B")
            return MCPHTTPResponse.json(MCPJSONRPC.error(id: nil, code: -32700, message: "Parse error"), statusCode: 400)
        }

        let method = object["method"] as? String ?? ""
        let id = object["id"]
        let params = object["params"] as? [String: Any] ?? [:]
        let isNotification = object["id"] == nil && !method.isEmpty

        MCPLogger.rpc.debug("RPC method=\(method, privacy: .public) id=\(String(describing: id), privacy: .public) notification=\(isNotification)")

        switch method {
        case "initialize":
            return handleInitialize(id: id)
        case "notifications/initialized", "initialized":
            isInitialized = true
            return .accepted(extraHeaders: sessionHeader(for: request))
        case "ping":
            return MCPHTTPResponse.json(
                MCPJSONRPC.success(id: id, result: [:]),
                extraHeaders: sessionHeader(for: request)
            )
        case "tools/list":
            return handleToolsList(id: id, request: request)
        case "tools/call":
            return handleToolsCall(id: id, params: params, request: request)
        default:
            if isNotification {
                MCPLogger.rpc.debug("Ignored notification method=\(method, privacy: .public)")
                return .accepted(extraHeaders: sessionHeader(for: request))
            }
            MCPLogger.rpc.error("Unknown method=\(method, privacy: .public)")
            return MCPHTTPResponse.json(
                MCPJSONRPC.error(id: id, code: -32601, message: "Method not found: \(method)"),
                statusCode: 400,
                extraHeaders: sessionHeader(for: request)
            )
        }
    }

    private func handleDelete(sessionID: String?) -> MCPHTTPResponse {
        if let sessionID {
            sessions.remove(sessionID)
            onCloseSession?(sessionID)
            MCPLogger.rpc.info("Session ended id=\(sessionID, privacy: .public) active=\(self.sessions.count)")
        }
        return MCPHTTPResponse(statusCode: 204, headers: ["Connection": "close", "Content-Length": "0"])
    }

    private func handleSSEGet(_ request: MCPHTTPRequest) -> MCPHTTPResponse {
        guard acceptsEventStream(request.headers) else {
            MCPLogger.http.error("GET /mcp rejected: missing text/event-stream Accept")
            return MCPHTTPResponse.text("Not Acceptable", statusCode: 406)
        }

        guard sessionIsValid(for: request) else {
            MCPLogger.rpc.error("GET SSE rejected: invalid session")
            return MCPHTTPResponse.text("Bad Request", statusCode: 400)
        }

        let sessionID = request.headers["mcp-session-id"] ?? ""
        MCPLogger.rpc.info("Opening SSE stream session=\(sessionID, privacy: .public)")
        return MCPHTTPResponse.sseStream(extraHeaders: sessionHeader(for: request), sessionID: sessionID)
    }

    private func handleInitialize(id: Any?) -> MCPHTTPResponse {
        let sessionID = UUID().uuidString.lowercased()
        sessions.insert(sessionID)
        isInitialized = true

        MCPLogger.rpc.info("Initialized session=\(sessionID, privacy: .public) protocol=\(MCPConfiguration.protocolVersion, privacy: .public)")

        let result: [String: Any] = [
            "protocolVersion": MCPConfiguration.protocolVersion,
            "capabilities": [
                "tools": ["listChanged": false]
            ],
            "serverInfo": [
                "name": MCPConfiguration.serverName,
                "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
            ]
        ]

        return MCPHTTPResponse.json(
            MCPJSONRPC.success(id: id, result: result),
            extraHeaders: ["Mcp-Session-Id": sessionID]
        )
    }

    private func handleToolsList(id: Any?, request: MCPHTTPRequest) -> MCPHTTPResponse {
        guard sessionIsValid(for: request) else {
            MCPLogger.rpc.error("tools/list rejected: invalid session")
            return MCPHTTPResponse.text("Bad Request", statusCode: 400)
        }

        let tools: [[String: Any]] = AIToolCatalog.mcpTools.map(\.mcpToolListEntry)

        MCPLogger.rpc.info("tools/list returned \(tools.count) tools (\(AIToolCatalog.writeTools.count) write proposals)")

        return MCPHTTPResponse.json(
            MCPJSONRPC.success(id: id, result: ["tools": tools]),
            extraHeaders: sessionHeader(for: request)
        )
    }

    private func handleToolsCall(id: Any?, params: [String: Any], request: MCPHTTPRequest) -> MCPHTTPResponse {
        guard sessionIsValid(for: request) else {
            MCPLogger.rpc.error("tools/call rejected: invalid session")
            return MCPHTTPResponse.text("Bad Request", statusCode: 400)
        }

        guard let name = params["name"] as? String else {
            MCPLogger.rpc.error("tools/call missing tool name")
            return MCPHTTPResponse.json(
                MCPJSONRPC.error(id: id, code: -32602, message: "Missing tool name"),
                statusCode: 400,
                extraHeaders: sessionHeader(for: request)
            )
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]
        let start = ContinuousClock.now
        let outcome = MCPToolService.call(name: name, arguments: arguments, container: container)
        let elapsed = start.duration(to: .now)
        let elapsedMs = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15

        if outcome.isError {
            MCPLogger.tools.error("tool=\(name, privacy: .public) failed in \(elapsedMs, format: .fixed(precision: 1))ms preview=\(MCPLogPreview.text(outcome.text), privacy: .public)")
        } else {
            MCPLogger.tools.info("tool=\(name, privacy: .public) ok in \(elapsedMs, format: .fixed(precision: 1))ms chars=\(outcome.text.count) args=\(MCPLogPreview.json(arguments), privacy: .public)")
        }

        let result: [String: Any] = [
            "content": [
                ["type": "text", "text": outcome.text]
            ],
            "isError": outcome.isError
        ]

        return MCPHTTPResponse.json(
            MCPJSONRPC.success(id: id, result: result),
            extraHeaders: sessionHeader(for: request)
        )
    }

    private func sessionIsValid(for request: MCPHTTPRequest) -> Bool {
        if let sessionID = request.headers["mcp-session-id"] {
            return sessions.contains(sessionID)
        }
        return isInitialized
    }

    private func sessionHeader(for request: MCPHTTPRequest) -> [String: String] {
        guard let sessionID = request.headers["mcp-session-id"] else { return [:] }
        return ["Mcp-Session-Id": sessionID]
    }

    private func acceptsMCP(_ headers: [String: String]) -> Bool {
        guard let accept = headers["accept"]?.lowercased() else { return true }
        return accept.contains("application/json") || accept.contains("text/event-stream") || accept.contains("*/*")
    }

    private func acceptsEventStream(_ headers: [String: String]) -> Bool {
        guard let accept = headers["accept"]?.lowercased() else { return false }
        return accept.contains("text/event-stream") || accept.contains("*/*")
    }
}

@MainActor
enum MCPToolService {
    static func call(name: String, arguments: [String: Any], container: ModelContainer) -> (text: String, isError: Bool) {
        guard let definition = AIToolCatalog.definition(named: name) else {
            MCPLogger.tools.error("Unknown tool=\(name, privacy: .public)")
            return ("Ferramenta '\(name)' não está disponível via MCP.", true)
        }

        if definition.isWrite {
            return MCPWriteProposalService.propose(name: name, arguments: arguments, container: container)
        }

        do {
            let context = try AIToolContextFactory.make(from: container)
            let payload = try AIToolReaders.execute(name: name, args: arguments, context: context)
            let json = AIToolJSON.encodeString(payload)
            if !payload.ok {
                MCPLogger.tools.error("tool=\(name, privacy: .public) returned ok=false preview=\(MCPLogPreview.text(json), privacy: .public)")
            }
            return (json, !payload.ok)
        } catch {
            MCPLogger.tools.error("tool=\(name, privacy: .public) threw \(error.localizedDescription, privacy: .public)")
            return (error.localizedDescription, true)
        }
    }
}

enum MCPLogPreview {
    static func text(_ value: String, limit: Int = 160) -> String {
        guard value.count > limit else { return value }
        return String(value.prefix(limit)) + "…"
    }

    static func json(_ value: [String: Any], limit: Int = 200) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text(string, limit: limit)
    }
}
