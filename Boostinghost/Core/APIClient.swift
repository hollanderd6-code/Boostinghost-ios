import Foundation

enum APIError: Error {
    case unauthorized
    case subscriptionRequired
    case server(statusCode: Int, message: String?)
    case decoding(Error)
    case network(Error)
}

actor APIClient {
    static let shared = APIClient()

    var token: String?

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    func setToken(_ token: String?) {
        self.token = token
    }

    // MARK: - GET

    func get<T: Decodable>(_ url: URL, agencyAll: Bool = false) async throws -> T {
        let finalURL = agencyAll ? appending(url, query: "agency", value: "all") : url
        return try await perform(makeRequest(url: finalURL, method: "GET"))
    }

    // MARK: - DELETE

    func delete(_ url: URL) async throws {
        let req = makeRequest(url: url, method: "DELETE")
        let (data, response) = try await send(req)
        try validate(response: response, data: data)
    }

    // MARK: - POST

    func post<T: Decodable, B: Encodable>(_ url: URL, body: B) async throws -> T {
        var req = makeRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    func postVoid<B: Encodable>(_ url: URL, body: B) async throws {
        var req = makeRequest(url: url, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await send(req)
        try validate(response: response, data: data)
    }

    // MARK: - Private

    private func makeRequest(url: URL, method: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return req
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await send(req)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            // TEMPORARY — retire après diagnostic bascule
            print("[APIClient] DECODE FAIL \(T.self): \(error)")
            print("[APIClient] RAW: \(String(data: data, encoding: .utf8) ?? "(non-UTF8)")")
            throw APIError.decoding(error)
        }
    }

    private func send(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network(error)
        }
    }

    private func validate(response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 403:
            let msg = errorMessage(from: data)
            if msg?.localizedCaseInsensitiveContains("abonnement") == true {
                throw APIError.subscriptionRequired
            }
            throw APIError.server(statusCode: 403, message: msg)
        default:
            throw APIError.server(statusCode: http.statusCode, message: errorMessage(from: data))
        }
    }

    private func errorMessage(from data: Data?) -> String? {
        guard let data else { return nil }
        return (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.firstMessage
    }

    private func appending(_ url: URL, query: String, value: String) -> URL {
        guard var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        var items = c.queryItems ?? []
        items.append(URLQueryItem(name: query, value: value))
        c.queryItems = items
        return c.url ?? url
    }
}

struct EmptyBody: Encodable {}

private struct ErrorEnvelope: Decodable {
    let error: String?
    let message: String?
    var firstMessage: String? { error ?? message }
}
