/// A step pushed onto the auth flow's `NavigationStack`, driven by `LoginViewModel.path`.
/// The root (email entry) step isn't included here — it's the `NavigationStack`'s root
/// view, never pushed. See `plans/ios-auth-flow-multi-step.md`.
public enum AuthFlowRoute: Hashable, Sendable {
    case createAccount
    case welcomeBack
    case verificationCode(VerificationPurpose)
    case forgotPasswordEmail
}

/// Why the verification-code screen is being shown. The shared screen's button/footer
/// copy, and what happens on a successful "Confirm", both depend on this.
public enum VerificationPurpose: Hashable, Sendable {
    case signUp
    case signIn
    case passwordReset
}
