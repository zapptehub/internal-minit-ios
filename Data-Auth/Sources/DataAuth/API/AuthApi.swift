import Foundation
import CoreNetworking

public protocol AuthApi: Sendable {
    func login(email: String, password: String) async throws -> AuthDto
    /// Whether `email` belongs to an existing account — drives the email-entry step's
    /// routing to Create Account (`false`) vs. Welcome Back (`true`).
    func checkEmailExists(email: String) async throws -> Bool
    func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthDto
    /// Sends a fresh verification code to `email`. No code is actually delivered — see
    /// `confirmPasswordReset`/the verification screen's "any code is accepted" mock.
    func sendVerificationCode(email: String) async throws
    /// Confirms a password reset for `email`. `code` is accepted unchecked (mock, no real
    /// OTP validation) — see `plans/ios-auth-flow-multi-step.md`.
    func confirmPasswordReset(email: String, code: String) async throws

    /// Reconstructs a session from the backend's own persisted identity (e.g. Firebase
    /// Auth's `currentUser`), refreshing the access token if needed. Returns `nil` when
    /// there is no persisted identity, or when it is no longer valid (revoked, disabled,
    /// deleted) — implementations should treat that case as "signed out" and clear their
    /// own persisted identity rather than surfacing it as an error. Any other thrown error
    /// (e.g. a network failure) means restoration could not be determined either way.
    func restoreSession() async throws -> AuthDto?

    /// Signs out of the backend's own persisted identity. Called in addition to clearing
    /// the local session cache so logout is authoritative on both sides.
    func signOut() async throws
}

public final class AuthApiImpl: AuthApi {
    private let networkClient: NetworkClient

    /// The one mock address that routes the email-entry step to Create Account — every
    /// other address is treated as an existing user (Welcome Back). Real backend not
    /// ready yet; see `plans/ios-auth-flow-multi-step.md`.
    private static let mockNewUserEmail = "new@minit.com"

    public init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }

    public func login(email: String, password: String) async throws -> AuthDto {
        // Mock: backend not ready — always returns a successful response
        return AuthDto(accessToken: "mock-token-\(UUID().uuidString)", userId: "mock-user-001")
    }

    public func checkEmailExists(email: String) async throws -> Bool {
        // Mock: backend not ready — see `Self.mockNewUserEmail`.
        let normalizedEmail = email.trimmingCharacters(in: .whitespaces).lowercased()
        return normalizedEmail != Self.mockNewUserEmail
    }

    public func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthDto {
        // Mock: backend not ready — always returns a successful response, same as `login`.
        return AuthDto(accessToken: "mock-token-\(UUID().uuidString)", userId: "mock-user-001")
    }

    public func sendVerificationCode(email: String) async throws {
        // Mock: backend not ready — no real code is sent.
    }

    public func confirmPasswordReset(email: String, code: String) async throws {
        // Mock: backend not ready — any code is accepted, nothing to validate.
    }

    public func restoreSession() async throws -> AuthDto? {
        // Mock: backend not ready — nothing persisted to restore.
        return nil
    }

    public func signOut() async throws {
        // Mock: backend not ready — nothing to sign out of.
    }
}
