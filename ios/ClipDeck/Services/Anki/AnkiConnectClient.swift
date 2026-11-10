import Foundation

enum AnkiError: LocalizedError, Equatable {
    case notConfigured
    case unreachable(String)
    case anki(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Add a valid AnkiConnect address (like http://192.168.1.20:8765) in Anki settings."
        case .unreachable(let address):
            return "Couldn't reach Anki at \(address). Open Anki on your computer, check AnkiConnect's webBindAddress is 0.0.0.0, and make sure both devices are on the same network."
        case .anki(let message):
            return "Anki said: \(message)"
        case .invalidResponse:
            return "The reply from AnkiConnect wasn't understood. Update the AnkiConnect add-on and try again."
        }
    }

    /// AnkiConnect rejects duplicates with "cannot create note because it is a duplicate".
    var isDuplicate: Bool {
        if case .anki(let message) = self { return message.lowercased().contains("duplicate") }
        return false
    }

    var isUnreachable: Bool {
        if case .unreachable = self { return true }
        return false
    }
}

/// The AnkiConnect actions the app uses. A protocol so sync logic can be tested without Anki.
protocol AnkiTransport {
    func version() async throws -> Int
    func deckNames() async throws -> [String]
    func modelNames() async throws -> [String]
    func modelFieldNames(_ modelName: String) async throws -> [String]
    func storeMediaFile(name: String, data: Data) async throws
    func addNote(deck: String, model: String, fields: [String: String], tags: [String]) async throws -> Int64
}

/// Talks to the AnkiConnect add-on (https://foosoft.net/projects/anki-connect/) over HTTP, API version 6.
struct AnkiConnectClient: AnkiTransport {
    var baseURL: URL
    var apiKey: String?
    var session: URLSession = .shared
    var timeout: TimeInterval = 8

    init(baseURL: URL, apiKey: String? = nil, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
    }

    /// Nil when the settings' address isn't a usable http(s) URL.
    init?(settings: AnkiSettings, session: URLSession = .shared) {
        var text = settings.url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty, !text.contains("://") { text = "http://" + text }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        self.init(baseURL: url, apiKey: settings.apiKey.isEmpty ? nil : settings.apiKey, session: session)
    }

    // MARK: Actions

    func version() async throws -> Int {
        try await call("version")
    }

    func deckNames() async throws -> [String] {
        try await call("deckNames")
    }

    func modelNames() async throws -> [String] {
        try await call("modelNames")
    }

    func modelFieldNames(_ modelName: String) async throws -> [String] {
        try await call("modelFieldNames", params: ["modelName": modelName])
    }

    func storeMediaFile(name: String, data: Data) async throws {
        let _: String = try await call("storeMediaFile", params: [
            "filename": name,
            "data": data.base64EncodedString(),
        ])
    }

    func addNote(deck: String, model: String, fields: [String: String], tags: [String]) async throws -> Int64 {
        try await call("addNote", params: [
            "note": [
                "deckName": deck,
                "modelName": model,
                "fields": fields,
                "tags": tags,
                "options": ["allowDuplicate": false, "duplicateScope": "deck"] as [String: Any],
            ] as [String: Any],
        ])
    }

    // MARK: Transport

    func makeRequest(action: String, params: [String: Any] = [:]) throws -> URLRequest {
        var body: [String: Any] = ["action": action, "version": 6]
        if !params.isEmpty { body["params"] = params }
        if let apiKey, !apiKey.isEmpty { body["key"] = apiKey }

        var request = URLRequest(url: baseURL, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    func call<Value: Decodable>(_ action: String, params: [String: Any] = [:]) async throws -> Value {
        let request = try makeRequest(action: action, params: params)
        let response: (Data, URLResponse)
        do {
            response = try await session.data(for: request)
        } catch {
            throw AnkiError.unreachable(baseURL.absoluteString)
        }
        return try Self.decode(response.0)
    }

    private struct Envelope<Value: Decodable>: Decodable {
        let result: Value?
        let error: String?
    }

    static func decode<Value: Decodable>(_ data: Data) throws -> Value {
        let envelope: Envelope<Value>
        do {
            envelope = try JSONDecoder().decode(Envelope<Value>.self, from: data)
        } catch {
            throw AnkiError.invalidResponse
        }
        if let message = envelope.error { throw AnkiError.anki(message) }
        guard let result = envelope.result else { throw AnkiError.invalidResponse }
        return result
    }
}
