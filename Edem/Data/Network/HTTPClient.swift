import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum NetworkError: LocalizedError {
    case invalidResponse
    case badStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Некорректный ответ сервера"
        case .badStatus(let code): return "Сервер вернул код \(code)"
        case .decoding: return "Не удалось разобрать ответ сервера"
        }
    }
}

/// Абстракция транспорта: позволяет подменять сеть в тестах.
protocol HTTPClient: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        return (data, http)
    }
}

/// JSON поверх HTTPClient.
struct JSONAPIClient: Sendable {
    let http: HTTPClient
    var timeout: TimeInterval = 15

    func get<Response: Decodable>(_ url: URL, as type: Response.Type = Response.self) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    func post<Body: Encodable, Response: Decodable>(
        _ url: URL,
        body: Body,
        as type: Response.Type = Response.self
    ) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        return try await perform(request)
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await http.send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw NetworkError.badStatus(response.statusCode)
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw NetworkError.decoding(error)
        }
    }
}
