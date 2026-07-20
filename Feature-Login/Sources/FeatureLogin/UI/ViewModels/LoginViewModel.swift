import Observation
import DataAuth
import CoreExtensions

@MainActor
@Observable
public final class LoginViewModel {
    public var email: String = ""
    public var password: String = ""
    public var state: AuthState = .idle
    public var errorMessage: String? = nil

    /// Re-entered password on the Create Account step — compared against `password` for
    /// the "Continue" enabled state; not used by any other step.
    public var confirmPassword: String = ""
    /// Marketing communications opt-in checkbox on the Create Account step.
    public var marketingOptIn: Bool = false
    /// The 4-digit code typed on the Verification Code step. Any value is accepted for
    /// now — see `plans/ios-auth-flow-multi-step.md`'s "OTP is always accepted" decision.
    public var otpCode: String = ""
    /// Whether `email` was routed to Create Account (`true`) or Welcome Back (`false`)
    /// after the email-entry step's "Continue". Set once real/mock email-existence
    /// checking lands — unused until then.
    public var isNewUser: Bool = false
    /// Drives the auth flow's `NavigationStack(path:)`. Screens push their next step by
    /// appending to this array; resetting to `[]` returns to the email-entry root.
    public var path: [AuthFlowRoute] = []
    /// Seconds remaining before "Send Again" is tappable on the Verification Code step.
    /// Starts at `Self.resendCooldownSeconds` (01:44) whenever that screen appears or a
    /// resend succeeds.
    public var resendCountdownSeconds: Int = 0
    /// One-shot signal flipped to `true` right after a successful password-reset OTP confirm.
    /// `FeatureLogin.createScreen(...)` observes this to dismiss the login sheet and hand off
    /// to a separate `PasswordChangedScreen` sheet — see `plans/password_changed_second_sheet_9f2e404f.plan.md`.
    public var passwordResetCompleted: Bool = false
    /// Drives the "under construction" system alert on `LoginScreen` for stubbed buttons
    /// (Apple/Google sign-in, Support links) until real integrations land.
    public var showsFeatureUnderConstructionAlert: Bool = false

    /// Matches Figma/screenshot countdown display (`01:44`).
    private static let resendCooldownSeconds = 104

    private let authRepository: AuthRepository
    private var countdownTask: Task<Void, Never>?

    public init(authRepository: AuthRepository) {
        self.authRepository = authRepository
    }

    public var canResendCode: Bool {
        resendCountdownSeconds == 0
    }

    public var resendCountdownFormatted: String {
        let minutes = resendCountdownSeconds / 60
        let seconds = resendCountdownSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Capitalized local part of `email` (before the "@"), used for the Welcome Back
    /// screen's "Welcome back <Name>" headline. E.g. "iveta@minitbakery.com" -> "Iveta".
    /// Falls back to the full `email` string if it contains no "@" (still typing, or
    /// invalid input) so the headline never renders empty.
    public var firstName: String {
        let localPart = email.split(separator: "@").first.map(String.init) ?? email
        return localPart.capitalized
    }

    public var isEmailValid: Bool { email.trimmed.isValidEmail }

    public var hasEmailFormatError: Bool { !email.isBlank && !isEmailValid }

    private func guardValidEmail() -> Bool {
        guard !email.isBlank else {
            errorMessage = String(localized: "login.error.emptyEmail", bundle: .module)
            return false
        }
        guard isEmailValid else {
            errorMessage = String(localized: "login.error.invalidEmail", bundle: .module)
            return false
        }
        return true
    }

    /// "Continue" on the email-entry step — looks up whether `email` belongs to an existing
    /// account and routes to Create Account or Welcome Back accordingly (mocked via
    /// `checkEmailExists`; see `plans/ios-auth-flow-multi-step.md`'s "new@minit.com" decision).
    public func continueFromEmail() {
        guard guardValidEmail() else { return }
        errorMessage = nil
        state = .loading
        Task {
            do {
                let exists = try await authRepository.checkEmailExists(email: email)
                isNewUser = !exists
                state = .idle
                path.append(exists ? .welcomeBack : .createAccount)
            } catch {
                let message = error.localizedDescription
                state = .error(message)
                errorMessage = message
            }
        }
    }

    /// "Continue" on the Create Account step. Client-side validation (non-empty, matching
    /// passwords, marketing checkbox — see `plans/ios-auth-flow-multi-step.md`) already gates
    /// the button's enabled state, so a failing guard here only fires from a stale/forced call.
    /// Registration itself doesn't happen yet — per the flow diagram, `register()` fires from
    /// the shared Verification Code screen's "Confirm", not here; this just sends the code and
    /// pushes that step.
    public func submitCreateAccount() {
        guard guardValidEmail() else { return }
        guard !password.isEmpty, password == confirmPassword else {
            errorMessage = String(localized: "createAccount.error.passwordMismatch", bundle: .module)
            return
        }
        errorMessage = nil
        state = .loading
        Task {
            do {
                try await authRepository.sendVerificationCode(email: email)
                state = .idle
                path.append(.verificationCode(.signUp))
            } catch {
                let message = error.localizedDescription
                state = .error(message)
                errorMessage = message
            }
        }
    }

    /// "Sign In" on the Welcome Back step — password is validated client-side (button already
    /// gated on non-empty). Actual `login()` fires from the Verification Code screen's
    /// "Confirm"; this just sends the code and pushes that step, same as `submitCreateAccount`.
    public func submitSignIn() {
        guard guardValidEmail() else { return }
        guard !password.isEmpty else {
            errorMessage = String(localized: "welcomeBack.error.emptyPassword", bundle: .module)
            return
        }
        errorMessage = nil
        state = .loading
        Task {
            do {
                try await authRepository.sendVerificationCode(email: email)
                state = .idle
                path.append(.verificationCode(.signIn))
            } catch {
                let message = error.localizedDescription
                state = .error(message)
                errorMessage = message
            }
        }
    }

    /// "Reset Password" on the Forgot Password Email step — sends a verification code and pushes
    /// the shared OTP screen with `.passwordReset` purpose.
    public func submitForgotPasswordEmail() {
        guard guardValidEmail() else { return }
        errorMessage = nil
        state = .loading
        Task {
            do {
                try await authRepository.sendVerificationCode(email: email)
                state = .idle
                path.append(.verificationCode(.passwordReset))
            } catch {
                let message = error.localizedDescription
                state = .error(message)
                errorMessage = message
            }
        }
    }

    /// "Forgot Password?" on the Welcome Back step — navigates to the forgot-password email screen.
    public func openForgotPassword() {
        path.append(.forgotPasswordEmail)
    }

    /// Called when the Verification Code screen appears — clears any stale OTP and starts
    /// the resend cooldown (code was just sent by the prior step).
    public func onVerificationScreenAppeared() {
        otpCode = ""
        errorMessage = nil
        startResendCountdown()
    }

    /// "Send Again" on the Verification Code step — mock resend + restart cooldown.
    public func resendCode() {
        guard canResendCode else { return }
        errorMessage = nil
        state = .loading
        Task {
            do {
                try await authRepository.sendVerificationCode(email: email)
                state = .idle
                otpCode = ""
                startResendCountdown()
            } catch {
                let message = error.localizedDescription
                state = .error(message)
                errorMessage = message
            }
        }
    }

    /// Primary action on the Verification Code step. Any 4-digit `otpCode` is accepted for
    /// now; sign-up/sign-in complete via `register()`/`login()`, password reset via
    /// `confirmPasswordReset()` then signals `passwordResetCompleted`.
    public func confirmVerification(purpose: VerificationPurpose) {
        guard otpCode.count == 4 else {
            errorMessage = String(localized: "verification.error.incompleteCode", bundle: .module)
            return
        }
        errorMessage = nil
        state = .loading
        Task {
            do {
                switch purpose {
                case .signUp:
                    let data = try await authRepository.register(
                        email: email,
                        password: password,
                        marketingOptIn: marketingOptIn
                    )
                    state = .authenticated(data)
                case .signIn:
                    let data = try await authRepository.login(email: email, password: password)
                    state = .authenticated(data)
                case .passwordReset:
                    try await authRepository.confirmPasswordReset(email: email, code: otpCode)
                    state = .idle
                    passwordResetCompleted = true
                }
            } catch {
                let message = error.localizedDescription
                state = .error(message)
                errorMessage = message
            }
        }
    }

    private func startResendCountdown() {
        resendCountdownSeconds = Self.resendCooldownSeconds
        countdownTask?.cancel()
        countdownTask = Task {
            while resendCountdownSeconds > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
                resendCountdownSeconds -= 1
            }
        }
    }

    public func login() {
        guard guardValidEmail() else { return }
        guard !password.isEmpty else {
            errorMessage = String(localized: "login.error.emptyFields", bundle: .module)
            return
        }
        state = .loading
        Task {
            do {
                let data = try await authRepository.login(email: email, password: password)
                state = .authenticated(data)
            } catch {
                let message = error.localizedDescription
                state = .error(message)
                errorMessage = message
            }
        }
    }

    public func clearError() {
        errorMessage = nil
        if case .error = state { state = .idle }
    }

    public func showFeatureUnderConstruction() {
        showsFeatureUnderConstructionAlert = true
    }

    public func dismissFeatureUnderConstructionAlert() {
        showsFeatureUnderConstructionAlert = false
    }

    // TODO: replace with real Sign in with Apple integration once available — visual +
    // analytics-only for now (see `ios-login-sheet-redesign` plan's known gaps).
    public func signInWithApple() {
        showFeatureUnderConstruction()
    }

    // TODO: replace with real Google Sign-In SDK integration once available — visual +
    // analytics-only for now (see `ios-login-sheet-redesign` plan's known gaps).
    public func signInWithGoogle() {
        showFeatureUnderConstruction()
    }
}
