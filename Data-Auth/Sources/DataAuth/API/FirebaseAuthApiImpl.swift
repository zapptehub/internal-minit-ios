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
}

private extension AuthDataResult {
    func toDto() async throws -> AuthDto {
        let idToken = try await user.getIDToken()
        return AuthDto(accessToken: idToken, userId: user.uid)
    }
}
