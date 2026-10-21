import Foundation
import CoreNetworking

/// Scheme, host, and port of the API base URL. The base path is not part of the match.
nonisolated struct RequestOrigin: Equatable, Sendable {
    let scheme: String
    let host: String
    let port: Int

    init?(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty,
              let port = components.port ?? Self.defaultPort(for: scheme) else {
            return nil
        }
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    init?(baseURL: String) {
        guard let url = URL(string: baseURL), let origin = RequestOrigin(url) else { return nil }
        self = origin
    }

    func matches(_ url: URL) -> Bool {
        guard let other = RequestOrigin(url) else { return false }
        return self == other
    }

    private static func defaultPort(for scheme: String) -> Int? {
        switch scheme {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }
}

/// Attaches `Authorization` and `CF-Access-*` only when the request origin matches the API
/// base, and refuses a redirect onto any other origin.
///
/// Explicitly nonisolated: the app target defaults to `MainActor`, and `URLSession` calls
/// this delegate off the main actor. Every stored property is an immutable `let`, and
/// `TokenProvider` is `Sendable`, so this `Sendable` conformance is compiler-checked.
/// The token and the Access secret are not logged.
nonisolated final class HostScopedSessionDelegate: NSObject, URLSessionTaskDelegate, Sendable {
    private let origin: RequestOrigin?
    private let tokenProvider: TokenProvider
    private let accessClientId: String
    private let accessClientSecret: String

    init(
        baseURL: String,
        tokenProvider: TokenProvider,
        accessClientId: String,
        accessClientSecret: String
    ) {
        self.origin = RequestOrigin(baseURL: baseURL)
        self.tokenProvider = tokenProvider
        self.accessClientId = Self.normalizedAccessValue(accessClientId)
        self.accessClientSecret = Self.normalizedAccessValue(accessClientSecret)
        super.init()
    }

    /// `$(...)` is an unexpanded Info.plist value. Sending that literal is never a credential.
    static func normalizedAccessValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            return ""
        }
        return trimmed
    }

    func prepare(_ request: URLRequest, forceRefresh: Bool) async -> URLRequest {
        var request = request
        guard let url = request.url, origin?.matches(url) == true else {
            request.removeCredentialHeaders()
            return request
        }

        let token = await tokenProvider.currentToken(forceRefresh: forceRefresh)
        request.applyAPICredentials(
            token: token,
            accessClientId: accessClientId,
            accessClientSecret: accessClientSecret
        )
        return request
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let url = request.url, origin?.matches(url) == true else {
            completionHandler(nil)
            return
        }

        let delegate = self
        Task {
            let prepared = await delegate.prepare(request, forceRefresh: false)
            completionHandler(prepared)
        }
    }
}

nonisolated extension URLRequest {
    static let authorizationHeader = "Authorization"
    static let accessClientIdHeader = "CF-Access-Client-Id"
    static let accessClientSecretHeader = "CF-Access-Client-Secret"
    static let accessHeaderPrefix = "cf-access-"

    mutating func removeCredentialHeaders() {
        setValue(nil, forHTTPHeaderField: Self.authorizationHeader)
        let names = allHTTPHeaderFields?.keys.filter {
            $0.lowercased().hasPrefix(Self.accessHeaderPrefix)
        } ?? []
        for name in names {
            setValue(nil, forHTTPHeaderField: name)
        }
    }

    mutating func applyAPICredentials(token: String?, accessClientId: String, accessClientSecret: String) {
        let trimmed = token?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            setValue(nil, forHTTPHeaderField: Self.authorizationHeader)
        } else {
            setValue("Bearer \(trimmed)", forHTTPHeaderField: Self.authorizationHeader)
        }

        if accessClientId.isEmpty || accessClientSecret.isEmpty {
            setValue(nil, forHTTPHeaderField: Self.accessClientIdHeader)
            setValue(nil, forHTTPHeaderField: Self.accessClientSecretHeader)
        } else {
            setValue(accessClientId, forHTTPHeaderField: Self.accessClientIdHeader)
            setValue(accessClientSecret, forHTTPHeaderField: Self.accessClientSecretHeader)
        }
    }

    func sentBearerToken() -> Bool {
        guard let value = value(forHTTPHeaderField: Self.authorizationHeader) else { return false }
        let prefix = "bearer "
        guard value.lowercased().hasPrefix(prefix) else { return false }
        return !value.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
