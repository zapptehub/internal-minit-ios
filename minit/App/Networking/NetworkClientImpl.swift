import Foundation
import CoreNetworking

final class NetworkClientImpl: NetworkClient {
    private let baseURL: String
    private let session: URLSession

    init(baseURL: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        let (data, response) = try await session.data(for: request)
        return try validate(data: data, response: response)
    }

    func request<T: Decodable, B: Encodable>(_ path: String, method: HTTPMethod, body: B) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        return try validate(data: data, response: response)
    }

    private func validate<T: Decodable>(data: Data, response: URLResponse) throws -> T {
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw NetworkError.statusCode(http.statusCode) }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
