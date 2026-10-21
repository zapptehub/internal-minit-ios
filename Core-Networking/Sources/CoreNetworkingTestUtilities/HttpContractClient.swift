import CoreNetworking
import Foundation

/// Opt-in switch for the HTTP contract.
///
/// `MINIT_ENV=test` on minit-api accepts an `alg=none` token and serves
/// `POST /v1/test/reset`. The test classes skip unless `MINIT_HTTP_CONTRACT`
/// is `1`. Nothing here starts an Auth emulator or a Firebase emulator.
public enum HttpContract {
    public static let optInEnvironmentVariable = "MINIT_HTTP_CONTRACT"
    public static let baseURL = "http://127.0.0.1:8080"
    public static let resetPath = "/v1/test/reset"

    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[optInEnvironmentVariable] == "1"
    }
}

/// Hand-built `alg=none` ID token. Empty signature, no `kid`.
///
/// `iss` is `https://securetoken.google.com/minit-dev-bfc4e` and `aud` is
/// `minit-dev-bfc4e`. `exp` is an hour ahead. `iat` and `auth_time` are the
/// current second, so they are not in the future. Each simulated user is one
/// `sub`. `sub` must be non-empty and at most 128 characters.
public enum ContractJwt {
    public static let projectID = "minit-dev-bfc4e"
    public static let issuer = "https://securetoken.google.com/\(projectID)"

    public static func token(subject: String, now: Date = Date()) -> String {
        precondition(
            !subject.isEmpty && subject.count <= 128,
            "sub must be non-empty and at most 128 characters"
        )
        let issued = Int(now.timeIntervalSince1970)
        let header = base64URL(#"{"alg":"none","typ":"JWT"}"#)
        let payload = """
        {"iss":\(jsonString(issuer)),"aud":\(jsonString(projectID)),\
        "sub":\(jsonString(subject)),"iat":\(issued),"auth_time":\(issued),\
        "exp":\(issued + 3_600)}
        """
        return header + "." + base64URL(payload) + "."
    }
}

/// Contract `NetworkClient`. Attaches `Authorization` and nothing else.
///
/// No Cloudflare Access headers and no 401 retry. `subject == nil` sends no
/// `Authorization`. `reset()` is `POST /v1/test/reset`.
public struct ContractHTTPClient: NetworkClient {
    public let subject: String?

    public init(subject: String?) {
        self.subject = subject
    }

    public func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        try await decode(path, method: method, body: nil)
    }

    public func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: B
    ) async throws -> T {
        try await decode(path, method: method, body: try JSONEncoder().encode(body))
    }

    public func data(_ url: URL) async throws -> Data {
        try await load(url, method: .GET, body: nil, json: false)
    }

    /// `POST /v1/test/reset`. The body is `{"status":"ok"}`.
    public func reset() async throws {
        let response: ResetBody = try await request(HttpContract.resetPath, method: .POST)
        guard response.status == "ok" else { throw NetworkError.invalidResponse }
    }

    private struct ResetBody: Decodable {
        let status: String
    }

    private var bearer: String? {
        guard let subject, !subject.isEmpty else { return nil }
        return "Bearer \(ContractJwt.token(subject: subject))"
    }

    private func decode<T: Decodable>(_ path: String, method: HTTPMethod, body: Data?) async throws -> T {
        guard let url = URL(string: HttpContract.baseURL + path) else { throw NetworkError.invalidURL }
        let data = try await load(url, method: method, body: body, json: body != nil)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    private func load(_ url: URL, method: HTTPMethod, body: Data?, json: Bool) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.cachePolicy = .reloadIgnoringLocalCacheData
        if json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        if let bearer {
            request.setValue(bearer, forHTTPHeaderField: "Authorization")
        }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await ContractURLSession.shared.data(for: request)
        } catch {
            throw NetworkError.unknown(error)
        }
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.statusCode(http.statusCode, data)
        }
        return data
    }
}

/// `URLSession` is safe to share across contract requests. The box keeps that
/// session off the client value.
private final class ContractURLSession: @unchecked Sendable {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [:]
        return URLSession(configuration: configuration)
    }()
}

private func jsonString(_ value: String) -> String {
    var encoded = "\""
    for character in value {
        switch character {
        case "\\":
            encoded.append("\\\\")
        case "\"":
            encoded.append("\\\"")
        default:
            encoded.append(character)
        }
    }
    encoded.append("\"")
    return encoded
}

private func base64URL(_ value: String) -> String {
    Data(value.utf8).base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
