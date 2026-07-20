/// Every method takes a `file` parameter — callers pass `#fileID` explicitly (see call sites
/// in `LoginViewModel`) so conforming loggers (e.g. `ConsoleAnalyticsAdapter`) can report where
/// the event was actually triggered, rather than their own adapter file. This can't be a
/// protocol-extension default value instead: a default-valued extension method with the same
/// signature as a protocol requirement causes infinite recursion at runtime for any conformance
/// that doesn't override it, and even for ones that do, `#fileID` would resolve to this file
/// rather than the real call site.
public protocol LoginAnalyticsTracking: Sendable {
    func trackLoginAttempt(file: String)
    func trackLoginSuccess(file: String)
    func trackLoginFailed(reason: String, file: String)
    /// Fired when the Apple sign-in pill is tapped. Analytics-only for now — no real
    /// Sign in with Apple integration yet (see `ios-login-sheet-redesign` plan's known gaps).
    func trackAppleSignInTapped(file: String)
    /// Fired when the Google sign-in pill is tapped. Analytics-only for now — no real
    /// Google Sign-In SDK integration yet (see `ios-login-sheet-redesign` plan's known gaps).
    func trackGoogleSignInTapped(file: String)
    /// Fired when "Reset Password" is submitted on the Forgot Password Email step, mirroring
    /// `trackLoginAttempt()`'s timing (right before the network call).
    func trackForgotPasswordRequested(file: String)
    /// Fired when the password-reset OTP is confirmed on the Verification Code step, right
    /// before `passwordResetCompleted` is set.
    func trackPasswordResetCompleted(file: String)
    /// Fired when "Continue" is tapped on the email-entry step, right before the email lookup.
    func trackEmailContinueTapped(file: String)
    /// Fired when "Forgot Password?" is tapped on the Welcome Back step (navigation only).
    func trackForgotPasswordLinkTapped(file: String)
    /// Fired when "Continue" is submitted on the Create Account step, right before sending the code.
    func trackSignUpAttempt(file: String)
    /// Fired when sign-up OTP confirmation succeeds on the Verification Code step.
    func trackSignUpSuccess(file: String)
    /// Fired when sign-up OTP confirmation fails on the Verification Code step.
    func trackSignUpFailed(reason: String, file: String)
    /// Fired when "Send Again" is tapped on the Verification Code step.
    func trackVerificationCodeResent(file: String)
    /// Fired when "Back to Login" is tapped on the Password Changed success sheet.
    func trackPasswordChangedBackToLoginTapped(file: String)
}
