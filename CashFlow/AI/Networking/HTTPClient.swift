import Foundation
import os

struct HTTPClient: Sendable {
    let session: URLSession
    let defaultTimeout: TimeInterval

    init(session: URLSession = .shared, defaultTimeout: TimeInterval = 30) {
        self.session = session
        self.defaultTimeout = defaultTimeout
    }

    func get<T: Decodable>(
        _ type: T.Type,
        url: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> T {
        var request = URLRequest(url: url, timeoutInterval: timeout ?? defaultTimeout)
        request.httpMethod = "GET"
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw AIError.decodingFailed
        }
    }

    func postJSON<Body: Encodable, Response: Decodable>(
        _ responseType: Response.Type,
        url: URL,
        body: Body,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) async throws -> Response {
        let effectiveTimeout = timeout ?? defaultTimeout
        var request = URLRequest(url: url, timeoutInterval: effectiveTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(body)

        let bodySize = request.httpBody?.count ?? 0
        AILogger.http.debug("POST \(url.absoluteString, privacy: .public) body=\(bodySize)B timeout=\(effectiveTimeout, format: .fixed(precision: 0))s")
        let start = Date()
        do {
            let (data, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(start)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            AILogger.http.debug("POST \(url.absoluteString, privacy: .public) status=\(status) response=\(data.count)B in \(elapsed, format: .fixed(precision: 2))s")
            try validate(response: response, data: data)
            do {
                return try JSONDecoder().decode(Response.self, from: data)
            } catch {
                let bodyPreview = String(data: data.prefix(400), encoding: .utf8) ?? "<binary>"
                AILogger.http.error("Decode failed for \(Response.self): \(error.localizedDescription, privacy: .public). Body: \(bodyPreview, privacy: .public)")
                throw AIError.decodingFailed
            }
        } catch {
            let elapsed = Date().timeIntervalSince(start)
            AILogger.http.error("POST \(url.absoluteString, privacy: .public) failed after \(elapsed, format: .fixed(precision: 2))s: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    func postStream(
        url: URL,
        body: Data,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let effectiveTimeout = timeout ?? defaultTimeout
                AILogger.http.debug("POST stream \(url.absoluteString, privacy: .public) body=\(body.count)B timeout=\(effectiveTimeout, format: .fixed(precision: 0))s")
                let start = Date()
                do {
                    var request = URLRequest(url: url, timeoutInterval: effectiveTimeout)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                    request.httpBody = body
                    let (bytes, response) = try await session.bytes(for: request)
                    let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                    AILogger.http.debug("POST stream \(url.absoluteString, privacy: .public) opened status=\(status) in \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s")
                    try validate(response: response, data: nil)
                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    AILogger.http.debug("POST stream \(url.absoluteString, privacy: .public) closed after \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s")
                    continuation.finish()
                } catch {
                    AILogger.http.error("POST stream \(url.absoluteString, privacy: .public) failed after \(Date().timeIntervalSince(start), format: .fixed(precision: 2))s: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func validate(response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else {
            throw AIError.providerError("Resposta inválida.")
        }
        guard (200...299).contains(http.statusCode) else {
            let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            if http.statusCode == 401 { throw AIError.invalidCredentials }
            throw AIError.providerError(Self.friendlyErrorMessage(body: body, statusCode: http.statusCode))
        }
    }

    private static func friendlyErrorMessage(body: String, statusCode: Int) -> String {
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            if message.hasPrefix("model:") {
                return "Modelo não encontrado ou descontinuado. Abra Inteligência → Anthropic e selecione um modelo atual."
            }
            return message
        }
        return body.isEmpty ? "HTTP \(statusCode)" : body
    }
}
