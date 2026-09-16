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

    func get<T: Decodable>(_ url: URL, agencyAll: Bool = false, extraQueryItems: [URLQueryItem] = []) async throws -> T {
        return try await perform(makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: extraQueryItems), method: "GET"))
    }

    // MARK: - GET raw data (PDF, binary)

    func getData(_ url: URL, agencyAll: Bool = false) async throws -> Data {
        let req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "GET")
        let (data, response) = try await send(req)
        try validate(response: response, data: data)
        return data
    }

    // MARK: - POST raw data (PDF streamé — body JSON optionnel)

    func postData<B: Encodable>(_ url: URL, body: B, agencyAll: Bool = false) async throws -> Data {
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await send(req)
        #if DEBUG
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[APIClient postData] URL: \(req.url?.absoluteString ?? "?")")
        print("[APIClient postData] req: \(req.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "(nil)")")
        print("[APIClient postData] → \(status)")
        print("[APIClient postData] res: \(String(data: data, encoding: .utf8) ?? "(non-UTF8)")")
        #endif
        try validate(response: response, data: data)
        return data
    }

    func postData(_ url: URL, agencyAll: Bool = false) async throws -> Data {
        let req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "POST")
        let (data, response) = try await send(req)
        try validate(response: response, data: data)
        return data
    }

    // MARK: - DELETE

    func delete(_ url: URL, agencyAll: Bool = false, extraQueryItems: [URLQueryItem] = []) async throws {
        let req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: extraQueryItems), method: "DELETE")
        let (data, response) = try await send(req)
        #if DEBUG
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[APIClient] DELETE \(req.url?.relativePath ?? "?") → \(status)")
        if !(200...299).contains(status) {
            print("[APIClient] err: \(String(data: data, encoding: .utf8) ?? "(non-UTF8)")")
        }
        #endif
        try validate(response: response, data: data)
    }

    // MARK: - POST

    // Variante sans corps (body vide, réponse typée, timeout configurable)
    func post<T: Decodable>(_ url: URL, agencyAll: Bool = false, timeout: TimeInterval = 60) async throws -> T {
        let req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "POST", timeout: timeout)
        return try await perform(req)
    }

    func post<T: Decodable, B: Encodable>(_ url: URL, body: B, agencyAll: Bool = false, extraQueryItems: [URLQueryItem] = []) async throws -> T {
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: extraQueryItems), method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    func postVoid<B: Encodable>(_ url: URL, body: B, agencyAll: Bool = false, extraQueryItems: [URLQueryItem] = []) async throws {
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: extraQueryItems), method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await send(req)
        try validate(response: response, data: data)
    }

    // MARK: - PUT

    func put<T: Decodable, B: Encodable>(_ url: URL, body: B, agencyAll: Bool = false, extraQueryItems: [URLQueryItem] = []) async throws -> T {
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: extraQueryItems), method: "PUT")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    func putVoid<B: Encodable>(_ url: URL, body: B, agencyAll: Bool = false, extraQueryItems: [URLQueryItem] = []) async throws {
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: extraQueryItems), method: "PUT")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await send(req)
        try validate(response: response, data: data)
    }

    // MARK: - PATCH (JSON)

    func patch<T: Decodable, B: Encodable>(_ url: URL, body: B, agencyAll: Bool = false) async throws -> T {
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "PATCH")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        return try await perform(req)
    }

    func patchVoid<B: Encodable>(_ url: URL, body: B, agencyAll: Bool = false) async throws {
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "PATCH")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await send(req)
        #if DEBUG
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[APIClient] PATCH \(req.url?.absoluteString ?? "?") → \(status)")
        if !(200...299).contains(status) {
            if let b = req.httpBody { print("[APIClient] req: \(String(data: b, encoding: .utf8) ?? "(binary)")") }
            print("[APIClient] err: \(String(data: data, encoding: .utf8) ?? "(non-UTF8)")")
        }
        #endif
        try validate(response: response, data: data)
    }

    // MARK: - POST multipart/form-data (champs texte + fichier optionnel)

    func postMultipartWithFile<T: Decodable>(
        _ url: URL,
        fields: [(String, String)],
        fileField: String? = nil,
        fileData: Data? = nil,
        fileName: String? = nil,
        fileMimeType: String? = nil,
        agencyAll: Bool = false
    ) async throws -> T {
        let boundary = "BH\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let hasFile = fileField != nil && fileData?.isEmpty == false
        var body = multipartBody(fields: fields, boundary: boundary, omitTerminator: hasFile)
        if hasFile, let ff = fileField, let fd = fileData, let fm = fileMimeType, !fd.isEmpty {
            let fname = fileName ?? "file"
            body.append(contentsOf: "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(ff)\"; filename=\"\(fname)\"\r\nContent-Type: \(fm)\r\n\r\n".utf8)
            body.append(fd)
            body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)
        }
        req.httpBody = body
        return try await perform(req)
    }

    // MARK: - POST multipart/form-data (image + text fields)

    func postMultipartUpload<T: Decodable>(
        _ url: URL,
        imageData: Data,
        mimeType: String,
        fileName: String = "photo.jpg",
        textFields: [(String, String)]
    ) async throws -> T {
        let boundary = "BH\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var req = makeRequest(url: url, method: "POST")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        for (name, value) in textFields {
            body.append(contentsOf: "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)
        }
        body.append(contentsOf: "--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"\(fileName)\"\r\nContent-Type: \(mimeType)\r\n\r\n".utf8)
        body.append(imageData)
        body.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)
        req.httpBody = body
        return try await perform(req)
    }

    // MARK: - PUT multipart/form-data (champs texte uniquement)

    func putMultipart<T: Decodable>(_ url: URL, fields: [(String, String)], agencyAll: Bool = false) async throws -> T {
        let boundary = "BH\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "PUT")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = multipartBody(fields: fields, boundary: boundary)
        return try await perform(req)
    }

    // MARK: - PUT multipart/form-data (champs texte + fichier optionnel)

    func putMultipartWithFile<T: Decodable>(
        _ url: URL,
        fields: [(String, String)],
        fileField: String? = nil,
        fileData: Data? = nil,
        fileName: String? = nil,
        fileMimeType: String? = nil,
        agencyAll: Bool = false
    ) async throws -> T {
        let boundary = "BH\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var req = makeRequest(url: buildURL(url, agencyAll: agencyAll, extra: []), method: "PUT")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = multipartBody(fields: fields, boundary: boundary)
        // Retirer le terminateur final avant d'insérer le fichier
        if let fileField, let fileData, let fileMimeType, !fileData.isEmpty {
            let fname = fileName ?? "file"
            var bodyWithFile = multipartBody(fields: fields, boundary: boundary, omitTerminator: true)
            bodyWithFile.append(contentsOf: "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fname)\"\r\nContent-Type: \(fileMimeType)\r\n\r\n".utf8)
            bodyWithFile.append(fileData)
            bodyWithFile.append(contentsOf: "\r\n--\(boundary)--\r\n".utf8)
            body = bodyWithFile
        }
        req.httpBody = body
        return try await perform(req)
    }

    private func multipartBody(fields: [(String, String)], boundary: String, omitTerminator: Bool = false) -> Data {
        var data = Data()
        for (name, value) in fields {
            data.append(contentsOf: "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8)
        }
        if !omitTerminator {
            data.append(contentsOf: "--\(boundary)--\r\n".utf8)
        }
        return data
    }

    // MARK: - Private

    private func makeRequest(url: URL, method: String, timeout: TimeInterval = 60) -> URLRequest {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return req
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response) = try await send(req)
        #if DEBUG
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        print("[APIClient] \(req.httpMethod ?? "?") \(req.url?.relativePath ?? "?") → \(status)")
        if !(200...299).contains(status) {
            if let b = req.httpBody { print("[APIClient] req: \(String(data: b, encoding: .utf8) ?? "(binary)")") }
            print("[APIClient] err: \(String(data: data, encoding: .utf8) ?? "(non-UTF8)")")
        }
        #endif
        try validate(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[APIClient] DECODE FAIL \(T.self): \(error)")
            print("[APIClient] RAW: \(String(data: data, encoding: .utf8) ?? "(non-UTF8)")")
            throw APIError.decoding(error)
        }
    }

    private func send(_ req: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: req)
        } catch {
            if error is CancellationError { throw error }
            if let urlErr = error as? URLError, urlErr.code == .cancelled { throw CancellationError() }
            throw APIError.network(error)
        }
    }

    private func validate(response: URLResponse, data: Data? = nil) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 401: throw APIError.unauthorized
        case 403:
            let env = data.flatMap { try? JSONDecoder().decode(ErrorEnvelope.self, from: $0) }
            if env?.featureBlocked == true {
                throw APIError.subscriptionRequired
            }
            let msg = env?.firstMessage
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

    private func buildURL(_ url: URL, agencyAll: Bool, extra: [URLQueryItem]) -> URL {
        var items = extra
        if agencyAll { items.append(URLQueryItem(name: "agency", value: "all")) }
        guard !items.isEmpty,
              var c = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        c.queryItems = (c.queryItems ?? []) + items
        return c.url ?? url
    }
}

struct EmptyBody: Encodable {}

extension APIError {
    /// Message à afficher dans les alertes — préfère le texte du serveur au libellé Swift générique.
    /// "Channex" (nom du prestataire de diffusion) est systématiquement masqué.
    var userMessage: String {
        func clean(_ s: String) -> String {
            s.replacingOccurrences(of: "Channex", with: "le prestataire de diffusion", options: .caseInsensitive)
        }
        switch self {
        case .unauthorized:                  return "Session expirée."
        case .subscriptionRequired:          return "Fonctionnalité réservée à l'abonnement actif."
        case .server(_, let msg):            return clean(msg ?? "Erreur serveur.")
        case .decoding(let e):               return "Réponse inattendue du serveur : \(e.localizedDescription)"
        case .network(let e):               return e.localizedDescription
        }
    }
}

private struct ErrorEnvelope: Decodable {
    let error: String?
    let message: String?
    let featureBlocked: Bool?
    var firstMessage: String? { error ?? message }
}
