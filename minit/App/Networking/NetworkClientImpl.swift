import Foundation
import CoreNetworking

final class NetworkClientImpl: NetworkClient {
    private let baseURL: String
    private let session: URLSession
    private let sessionDelegate: HostScopedSessionDelegate

    /// `sessionConfiguration` defaults to `.default`, whose `URLCache` stores responses
    /// that send `Cache-Control`. `data(_:)` may use that cache (avatar bytes).
    /// `request(...)` sets `.reloadIgnoringLocalCacheData` so authenticated JSON is not
    /// served from that URL-keyed cache after a different user signs in. Tests pass an
    /// ephemeral configuration. The delegate is retained here as well as by the session.
    /// Parallel 401s are not coalesced; Firebase already coalesces `getIDToken`.
    init(
        baseURL: String,
        tokenProvider: TokenProvider,
        accessClientId: String = "",
        accessClientSecret: String = "",
        sessionConfiguration: URLSessionConfiguration = .default
    ) {
        self.baseURL = baseURL
        let sessionDelegate = HostScopedSessionDelegate(
            baseURL: baseURL,
            tokenProvider: tokenProvider,
            accessClientId: accessClientId,
            accessClientSecret: accessClientSecret
        )
        self.sessionDelegate = sessionDelegate
        self.session = URLSession(
            configuration: Self.configurationWithoutCredentialDefaults(sessionConfiguration),
            delegate: sessionDelegate,
            delegateQueue: nil
        )
    }

    /// `URLSession` retains the delegate until the session is invalidated. Each test
    /// builds its own client; cancelling here releases that session.
    deinit {
        session.invalidateAndCancel()
    }

    /// `httpAdditionalHeaders` are applied to every request the session sends, including
    /// ones whose URLRequest has had the header removed. Credential headers belong on the
    /// API origin only, so they are dropped from the session defaults. A copy is used so
    /// the caller's configuration, including `.default`, is left unchanged.
    private static func configurationWithoutCredentialDefaults(
        _ configuration: URLSessionConfiguration
    ) -> URLSessionConfiguration {
        guard let copy = configuration.copy() as? URLSessionConfiguration else { return configuration }
        guard var headers = copy.httpAdditionalHeaders, !headers.isEmpty else { return copy }
        for key in headers.keys {
            let name = key as? String ?? String(describing: key)
            let lowered = name.lowercased()
            if lowered == "authorization" || lowered.hasPrefix(URLRequest.accessHeaderPrefix) {
                headers.removeValue(forKey: key)
            }
        }
        copy.httpAdditionalHeaders = headers
        return copy
    }

    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        return try decode(try await perform(try makeAPIRequest(path: path, method: method)))
    }

    func request<T: Decodable, B: Encodable>(_ path: String, method: HTTPMethod, body: B) async throws -> T {
        var request = try makeAPIRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        return try decode(try await perform(request))
    }

    /// JSON calls ignore the session `URLCache`. `data(_:)` keeps the default policy.
    private func makeAPIRequest(path: String, method: HTTPMethod) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else { throw NetworkError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    func data(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.GET.rawValue
        let (data, http) = try await perform(request)
        guard (200..<300).contains(http.statusCode) else {
            throw NetworkError.statusCode(http.statusCode, data)
        }
        return data
    }

    /// Same host check `data` and `request` use. Visible to tests that pre-seed headers.
    func preparedRequest(_ request: URLRequest, forceRefresh: Bool = false) async -> URLRequest {
        await sessionDelegate.prepare(request, forceRefresh: forceRefresh)
    }

    /// One forced refresh after a 401 that was sent with a bearer token. A nil or empty
    /// refreshed token skips the retry and returns the first response. Otherwise the
    /// second response, including a second 401, is returned as-is.
    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let prepared = await sessionDelegate.prepare(request, forceRefresh: false)
        let first = try await load(prepared)
        guard first.response.statusCode == 401, prepared.sentBearerToken() else {
            return first
        }
        let retried = await sessionDelegate.prepare(request, forceRefresh: true)
        guard retried.sentBearerToken() else {
            return first
        }
        return try await load(retried)
    }

    private func load(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw NetworkError.invalidResponse }
        return (data, http)
    }

    private func decode<T: Decodable>(_ payload: (data: Data, response: HTTPURLResponse)) throws -> T {
        guard (200..<300).contains(payload.response.statusCode) else {
            throw NetworkError.statusCode(payload.response.statusCode, payload.data)
        }
        do {
            return try JSONDecoder().decode(T.self, from: payload.data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}
