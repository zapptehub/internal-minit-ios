import Foundation

/// Bearer value for the shared HTTP client.
///
/// No identity-provider types. `nil` means there is no session. An empty string
/// is treated the same as `nil` by `NetworkClientImpl`.
///
/// A failed refresh is also `nil`. This method does not throw, so the caller cannot
/// tell a missing session from a token-endpoint failure. The client then sends no
/// `Authorization`, and a 401 on that request is not retried. When the first request
/// did send a bearer and the forced refresh returns `nil` or an empty token, the
/// client returns that first response and does not send a second, anonymous request.
/// The caller sees the HTTP status and body, not the underlying token error.
public protocol TokenProvider: Sendable {
    func currentToken(forceRefresh: Bool) async -> String?
}
