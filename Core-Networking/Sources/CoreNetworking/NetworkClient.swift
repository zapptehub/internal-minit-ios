import Foundation

public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case PATCH
    case DELETE
}

public enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    /// Non-2xx response. The associated `Data` is the response body, which may be empty.
    case statusCode(Int, Data)
    case decodingFailed(Error)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .statusCode(let code, _): return "Server returned status code \(code)"
        case .decodingFailed: return "Failed to decode response"
        case .unknown(let error): return error.localizedDescription
        }
    }
}

public protocol NetworkClient: Sendable {
    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T
    func request<T: Decodable, B: Encodable>(_ path: String, method: HTTPMethod, body: B) async throws -> T
    /// GET the absolute `url` and return the response body.
    func data(_ url: URL) async throws -> Data
}
