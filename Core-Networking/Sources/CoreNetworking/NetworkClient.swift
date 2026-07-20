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
    case statusCode(Int)
    case decodingFailed(Error)
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .statusCode(let code): return "Server returned status code \(code)"
        case .decodingFailed: return "Failed to decode response"
        case .unknown(let error): return error.localizedDescription
        }
    }
}

public protocol NetworkClient: Sendable {
    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T
    func request<T: Decodable, B: Encodable>(_ path: String, method: HTTPMethod, body: B) async throws -> T
}
