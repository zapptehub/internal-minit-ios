import DataAuth

/// Minimal no-op conformances shared by every screen's `#Preview` in this module —
/// `LoginTestUtilities` depends on `FeatureLogin`, so it can't be used here without a cycle.
struct PreviewAuthRepository: AuthRepository {
    func login(email: String, password: String) async throws -> AuthData {
        AuthData(token: "preview-token", userId: "preview-user")
    }
    func logout() async {}
    func currentSession() async -> AuthData? { nil }
    func checkEmailExists(email: String) async throws -> Bool { true }
    func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthData {
        AuthData(token: "preview-token", userId: "preview-user")
    }
    func sendVerificationCode(email: String) async throws {}
    func confirmPasswordReset(email: String, code: String) async throws {}
}

struct PreviewLoginAnalyticsTracking: LoginAnalyticsTracking {
    func trackLoginAttempt(file: String = #fileID) {}
    func trackLoginSuccess(file: String = #fileID) {}
    func trackLoginFailed(reason: String, file: String = #fileID) {}
    func trackAppleSignInTapped(file: String = #fileID) {}
    func trackGoogleSignInTapped(file: String = #fileID) {}
    func trackForgotPasswordRequested(file: String = #fileID) {}
    func trackPasswordResetCompleted(file: String = #fileID) {}
    func trackEmailContinueTapped(file: String = #fileID) {}
    func trackForgotPasswordLinkTapped(file: String = #fileID) {}
    func trackSignUpAttempt(file: String = #fileID) {}
    func trackSignUpSuccess(file: String = #fileID) {}
    func trackSignUpFailed(reason: String, file: String = #fileID) {}
    func trackVerificationCodeResent(file: String = #fileID) {}
    func trackPasswordChangedBackToLoginTapped(file: String = #fileID) {}
}
