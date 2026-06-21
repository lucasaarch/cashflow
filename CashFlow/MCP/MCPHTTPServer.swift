import Foundation
import Network
import os

final class MCPHTTPServer {
    typealias RequestHandler = @MainActor (MCPHTTPRequest) -> MCPHTTPResponse

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.lucasarch.cashflow.mcp.http", qos: .userInitiated)
    private var handler: RequestHandler?
    private var activeSSE: [String: NWConnection] = [:]
    private var keepaliveWorkItems: [ObjectIdentifier: DispatchWorkItem] = [:]

    private static let sseKeepaliveInterval: TimeInterval = 30

    func start(host: String = MCPConfiguration.host, port: UInt16 = MCPConfiguration.port, handler: @escaping RequestHandler) throws {
        stop()
        self.handler = handler

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw MCPHTTPServerError.invalidPort
        }

        params.requiredLocalEndpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: nwPort
        )
        listener = try NWListener(using: params)

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                MCPLogger.http.info("Listener ready on \(host, privacy: .public):\(port)")
            case .failed(let error):
                MCPLogger.http.error("Listener failed: \(error.localizedDescription, privacy: .public)")
            case .cancelled:
                MCPLogger.http.debug("Listener cancelled")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }

        listener?.start(queue: queue)
    }

    func stop() {
        queue.async { [weak self] in
            self?.closeAllSSEStreams()
        }
        listener?.cancel()
        listener = nil
        handler = nil
    }

    func closeSSEStream(sessionID: String) {
        queue.async { [weak self] in
            guard let self, let connection = self.activeSSE.removeValue(forKey: sessionID) else { return }
            self.cancelKeepalive(for: connection)
            connection.cancel()
        }
    }

    private func closeAllSSEStreams() {
        activeSSE.values.forEach { connection in
            cancelKeepalive(for: connection)
            connection.cancel()
        }
        activeSSE.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        MCPLogger.http.debug("Incoming connection")
        connection.stateUpdateHandler = { state in
            if case .failed = state {
                connection.cancel()
            }
        }
        connection.start(queue: queue)
        receive(connection: connection, accumulated: Data())
    }

    private func receive(connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else {
                connection.cancel()
                return
            }

            if let error {
                MCPLogger.http.error("Connection error: \(error.localizedDescription, privacy: .public)")
                connection.cancel()
                return
            }

            var buffer = accumulated
            if let data {
                buffer.append(data)
            }

            if let request = MCPHTTPParser.parse(buffer) {
                Task { @MainActor in
                    let start = ContinuousClock.now
                    let response = self.dispatch(request)
                    let elapsed = start.duration(to: .now)
                    let elapsedMs = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
                    MCPLogger.http.debug("\(request.method, privacy: .public) \(request.path, privacy: .public) -> \(response.statusCode) in \(elapsedMs, format: .fixed(precision: 1))ms body=\(request.body.count)B")
                    self.send(response, on: connection)
                }
                return
            }

            if isComplete {
                connection.cancel()
                return
            }

            self.receive(connection: connection, accumulated: buffer)
        }
    }

    @MainActor
    private func dispatch(_ request: MCPHTTPRequest) -> MCPHTTPResponse {
        guard let handler else {
            return MCPHTTPResponse.text("Service Unavailable", statusCode: 503)
        }
        return handler(request)
    }

    private func send(_ response: MCPHTTPResponse, on connection: NWConnection) {
        var headerLines = ["HTTP/1.1 \(response.statusCode) \(HTTPStatusPhrase.phrase(for: response.statusCode))"]
        for (key, value) in response.headers.sorted(by: { $0.key < $1.key }) {
            headerLines.append("\(canonicalHeaderName(key)): \(value)")
        }

        if response.keepsConnectionOpen {
            headerLines.append("")
            headerLines.append("")
            let data = Data(headerLines.joined(separator: "\r\n").utf8)
            connection.send(content: data, completion: .contentProcessed { [weak self] _ in
                guard let self else { return }
                if let sessionID = response.sseSessionID, !sessionID.isEmpty {
                    if let existing = self.activeSSE.removeValue(forKey: sessionID) {
                        self.cancelKeepalive(for: existing)
                        existing.cancel()
                    }
                    self.activeSSE[sessionID] = connection
                }
                self.startSSEKeepalive(on: connection)
            })
            return
        }

        if !response.headers.keys.contains(where: { $0.lowercased() == "content-length" }) {
            headerLines.append("Content-Length: \(response.body.count)")
        }
        headerLines.append("")
        headerLines.append("")

        var data = Data(headerLines.joined(separator: "\r\n").utf8)
        data.append(response.body)

        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func startSSEKeepalive(on connection: NWConnection) {
        func schedule() {
            let keepalive = Data(": keepalive\r\n\r\n".utf8)
            connection.send(content: keepalive, completion: .contentProcessed { [weak self] error in
                guard let self, error == nil else { return }
                let work = DispatchWorkItem { schedule() }
                self.keepaliveWorkItems[ObjectIdentifier(connection)] = work
                self.queue.asyncAfter(deadline: .now() + Self.sseKeepaliveInterval, execute: work)
            })
        }
        schedule()
    }

    private func cancelKeepalive(for connection: NWConnection) {
        keepaliveWorkItems.removeValue(forKey: ObjectIdentifier(connection))?.cancel()
    }
}

enum MCPHTTPServerError: LocalizedError {
    case invalidPort

    var errorDescription: String? {
        switch self {
        case .invalidPort: return "Porta MCP inválida."
        }
    }
}

enum MCPHTTPParser {
    static func parse(_ data: Data) -> MCPHTTPRequest? {
        guard let range = data.range(of: Data([13, 10, 13, 10])) else { return nil }
        let headerData = data.subdata(in: 0..<range.lowerBound)
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }

        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return nil }
        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return nil }

        let method = parts[0]
        let rawPath = parts[1]
        let path = URL(string: rawPath)?.path ?? rawPath

        var headers: [String: String] = [:]
        for line in lines.dropFirst() where line.contains(":") {
            let split = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard split.count == 2 else { continue }
            headers[split[0].lowercased()] = split[1]
        }

        let bodyStart = range.upperBound
        var body = data.subdata(in: bodyStart..<data.count)

        if let contentLength = headers["content-length"], let length = Int(contentLength), body.count >= length {
            body = body.prefix(length)
        } else if headers["content-length"] != nil {
            return nil
        }

        return MCPHTTPRequest(method: method, path: path, headers: headers, body: body)
    }
}

enum HTTPStatusPhrase {
    static func phrase(for code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 202: return "Accepted"
        case 204: return "No Content"
        case 400: return "Bad Request"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 406: return "Not Acceptable"
        case 503: return "Service Unavailable"
        default: return "OK"
        }
    }
}

private func canonicalHeaderName(_ key: String) -> String {
    switch key.lowercased() {
    case "content-type": return "Content-Type"
    case "content-length": return "Content-Length"
    case "connection": return "Connection"
    case "mcp-session-id": return "Mcp-Session-Id"
    case "accept": return "Accept"
    case "cache-control": return "Cache-Control"
    case "x-accel-buffering": return "X-Accel-Buffering"
    default: return key
    }
}
