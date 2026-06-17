import Foundation

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
        var request = URLRequest(url: url, timeoutInterval: timeout ?? defaultTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AIError.decodingFailed
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
                do {
                    var request = URLRequest(url: url, timeoutInterval: timeout ?? defaultTimeout)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
                    request.httpBody = body
                    let (bytes, response) = try await session.bytes(for: request)
                    try validate(response: response, data: nil)
                    for try await line in bytes.lines {
                        continuation.yield(line)
                    }
                    continuation.finish()
                } catch {
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
            throw AIError.providerError(body.isEmpty ? "HTTP \(http.statusCode)" : body)
        }
    }
}
