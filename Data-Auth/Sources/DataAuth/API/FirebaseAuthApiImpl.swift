import Foundation
import FirebaseAuth

/// Real `AuthApi` implementation backed by Firebase Authentication (email/password only).
/// This is the sole place in the app that imports `FirebaseAuth` — everything outside
/// `Data-Auth` only ever sees the `AuthApi`/`AuthRepository` protocols, so swapping Firebase
/// for the in-house backend later only touches this file (and `AuthDataModule`).
///
/// `sendVerificationCode`/`confirmPasswordReset` stay mocked no-ops, matching the existing
/// "OTP is always accepted" verification-code step — see `AuthApiImpl` and
/// `plans/ios-auth-flow-multi-step.md`. Apple/Google sign-in remain out of scope.
public final class FirebaseAuthApiImpl: AuthApi {
    public init() {}

    public func login(email: String, password: String) async throws -> AuthDto {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return try await result.toDto()
    }

    /// `fetchSignInMethods` is deprecated by Firebase (superseded by "Email Enumeration
    /// Protection", which makes it always return an empty list once enabled). This dev
    /// project has that protection explicitly disabled in the Firebase console — see
    /// Part A of the setup plan — specifically so this still works for routing the
    /// email-entry step to Create Account vs. Welcome Back. Revisit if Firebase removes
    /// this method entirely.
    public func checkEmailExists(email: String) async throws -> Bool {
        let methods = try await Auth.auth().fetchSignInMethods(forEmail: email)
        return !methods.isEmpty
    }

    public func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthDto {
        // `marketingOptIn` isn't persisted by Firebase Auth itself — same as the previous
        // mock, it's collected on the Create Account screen but not sent anywhere yet.
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return try await result.toDto()
    }

    public func sendVerificationCode(email: String) async throws {
        // Mock: not wired to a real Firebase mechanism yet — see the verification-code
        // step's "any code is accepted" behavior.
    }

    public func confirmPasswordReset(email: String, code: String) async throws {
        // Mock: any code is accepted, nothing to validate — see `sendVerificationCode`.
    }

    /// Firebase Auth persists `currentUser` across launches (keychain-backed), independent
    /// of this package's own in-memory session cache. Restoring from it — rather than only
    /// trusting the in-memory cache — is what lets a relaunch resume an existing session.
    ///
    /// `getIDToken()` returns the cached token when it isn't expired and only talks to the
    /// network to refresh it when it is, so this is cheap on the common path.
    public func restoreSession() async throws -> AuthDto? {
        guard let user = Auth.auth().currentUser else {
            return nil
        }

        do {
            let idToken = try await user.getIDToken()
            return AuthDto(accessToken: idToken, userId: user.uid)
        } catch {
            guard Self.isRevokedSessionError(error) else {
                // Could not determine validity either way (e.g. offline) — surface it so
                // the caller can distinguish "definitely signed out" from "try again".
                throw error
            }
            // The persisted identity itself is no longer valid (token revoked, account
            // disabled/deleted). Sign out locally too so Firebase Auth stops reporting a
            // `currentUser` that can never successfully refresh.
            try? Auth.auth().signOut()
            return nil
        }
    }

    public func signOut() async throws {
        try Auth.auth().signOut()
    }

    /// Error codes where the persisted Firebase Auth identity is permanently invalid rather
    /// than just temporarily unreachable — see `AuthErrorCode` in FirebaseAuth.
    private static func isRevokedSessionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == AuthErrors.domain else { return false }
        let revokedCodes: Set<Int> = [
            AuthErrorCode.userTokenExpired.rawValue,
            AuthErrorCode.userDisabled.rawValue,
            AuthErrorCode.userNotFound.rawValue,
            AuthErrorCode.invalidUserToken.rawValue
        ]
        return revokedCodes.contains(nsError.code)
    }
}

private extension AuthDataResult {
    func toDto() async throws -> AuthDto {
        let idToken = try await user.getIDToken()
        return AuthDto(accessToken: idToken, userId: user.uid)
    }
}
