import XCTest
@testable import FeatureLogin
import DataAuth
import CoreExtensions

@MainActor
final class LoginViewModelTests: XCTestCase {
    func testLoginSuccessUpdatesState() async {
        let mockRepo = MockAuthRepository()
        let vm = LoginViewModel(authRepository: mockRepo)

        vm.email = "test@example.com"
        vm.password = "password"
        vm.login()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(vm.state.authData)
    }

    func testLoginFailureUpdatesErrorState() async {
        let mockRepo = MockAuthRepository()
        mockRepo.shouldThrow = true
        let vm = LoginViewModel(authRepository: mockRepo)

        vm.email = "test@example.com"
        vm.password = "password"
        vm.login()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(vm.errorMessage)
    }

    func testLoginWithEmptyFieldsSetErrorMessage() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.login()

        XCTAssertNotNil(vm.errorMessage)
    }

    func testSignInWithAppleShowsUnderConstructionAlert() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.signInWithApple()

        XCTAssertTrue(vm.showsFeatureUnderConstructionAlert)
    }

    func testSignInWithGoogleShowsUnderConstructionAlert() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.signInWithGoogle()

        XCTAssertTrue(vm.showsFeatureUnderConstructionAlert)
    }

    func testDismissFeatureUnderConstructionAlert() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.showFeatureUnderConstruction()
        vm.dismissFeatureUnderConstructionAlert()

        XCTAssertFalse(vm.showsFeatureUnderConstructionAlert)
    }

    func testFirstNameCapitalizesLocalPartOfEmail() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.email = "iveta@minitbakery.com"

        XCTAssertEqual(vm.firstName, "Iveta")
    }

    func testFirstNameFallsBackToFullStringWithoutAtSign() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.email = "iveta"

        XCTAssertEqual(vm.firstName, "Iveta")
    }

    func testNewViewModelHasEmptyNavigationPath() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        XCTAssertTrue(vm.path.isEmpty)
        XCTAssertFalse(vm.isNewUser)
        XCTAssertFalse(vm.marketingOptIn)
    }

    func testContinueFromEmailWithEmptyEmailSetsErrorMessage() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.continueFromEmail()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testContinueFromEmailWithInvalidEmailSetsErrorMessage() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "iveta"

        vm.continueFromEmail()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertFalse(vm.isEmailValid)
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testContinueFromEmailWithInvalidEmailFormatMessage() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "user@"

        vm.continueFromEmail()

        XCTAssertEqual(
            vm.errorMessage,
            String(localized: "login.error.invalidEmail", bundle: .module)
        )
    }

    func testHasEmailFormatErrorWhenNonEmptyAndInvalid() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "iveta"

        XCTAssertTrue(vm.hasEmailFormatError)
    }

    func testHasEmailFormatErrorFalseWhenEmpty() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        XCTAssertFalse(vm.hasEmailFormatError)
    }

    func testContinueFromEmailRoutesToWelcomeBackForExistingUser() async {
        let mockRepo = MockAuthRepository()
        mockRepo.checkEmailExistsResult = true
        let vm = LoginViewModel(authRepository: mockRepo)

        vm.email = "iveta@minitbakery.com"
        vm.continueFromEmail()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.path, [.welcomeBack])
        XCTAssertFalse(vm.isNewUser)
    }

    func testSubmitCreateAccountWithMismatchedPasswordsSetsErrorMessage() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.email = "new@minit.com"
        vm.password = "password1"
        vm.confirmPassword = "password2"
        vm.submitCreateAccount()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.path.isEmpty)
    }

    /// Guards against the password-length error only surfacing once `register()` fires from
    /// `confirmVerification()` — by then we've already navigated past the Create Account
    /// screen, so a Firebase "password too short" error would show up on the Verification
    /// Code screen, which has no password field.
    func testSubmitCreateAccountWithTooShortPasswordSetsErrorMessageAndDoesNotNavigate() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.email = "new@minit.com"
        vm.password = "abc12"
        vm.confirmPassword = "abc12"
        vm.submitCreateAccount()

        XCTAssertEqual(
            vm.errorMessage,
            String(localized: "createAccount.error.passwordTooShort", bundle: .module)
        )
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testHasPasswordLengthErrorWhenNonEmptyAndTooShort() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.password = "abc12"

        XCTAssertTrue(vm.hasPasswordLengthError)
    }

    func testHasPasswordLengthErrorFalseWhenEmpty() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        XCTAssertFalse(vm.hasPasswordLengthError)
    }

    func testHasPasswordLengthErrorFalseWhenLongEnough() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.password = "abcdef"

        XCTAssertFalse(vm.hasPasswordLengthError)
    }

    func testSubmitCreateAccountWithMatchingPasswordsPushesVerificationCode() async {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.email = "new@minit.com"
        vm.password = "password1"
        vm.confirmPassword = "password1"
        vm.submitCreateAccount()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.path, [.verificationCode(.signUp)])
        XCTAssertNil(vm.errorMessage)
    }

    func testSubmitSignInWithEmptyPasswordSetsErrorMessage() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.email = "iveta@minitbakery.com"
        vm.submitSignIn()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testSubmitSignInWithPasswordPushesVerificationCode() async {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.email = "iveta@minitbakery.com"
        vm.password = "password1"
        vm.submitSignIn()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.path, [.verificationCode(.signIn)])
        XCTAssertNil(vm.errorMessage)
    }

    func testContinueFromEmailRoutesToCreateAccountForNewUser() async {
        let mockRepo = MockAuthRepository()
        mockRepo.checkEmailExistsResult = false
        let vm = LoginViewModel(authRepository: mockRepo)

        vm.email = "new@minit.com"
        vm.continueFromEmail()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.path, [.createAccount])
        XCTAssertTrue(vm.isNewUser)
    }

    func testOpenForgotPasswordNavigatesToForgotPasswordEmail() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.openForgotPassword()

        XCTAssertEqual(vm.path, [.forgotPasswordEmail])
    }

    func testOnVerificationScreenAppearedStartsCountdownAndClearsOTP() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.otpCode = "1234"
        vm.errorMessage = "stale"

        vm.onVerificationScreenAppeared()

        XCTAssertEqual(vm.otpCode, "")
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.resendCountdownSeconds, 104)
        XCTAssertEqual(vm.resendCountdownFormatted, "01:44")
        XCTAssertFalse(vm.canResendCode)
    }

    func testConfirmVerificationIncompleteCodeSetsError() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.otpCode = "12"

        vm.confirmVerification(purpose: .signIn)

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertNil(vm.state.authData)
    }

    func testConfirmVerificationSignUpAuthenticates() async {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "new@minit.com"
        vm.password = "password"
        vm.marketingOptIn = true
        vm.otpCode = "1234"

        vm.confirmVerification(purpose: .signUp)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(vm.state.authData)
        XCTAssertNil(vm.errorMessage)
    }

    func testConfirmVerificationSignInAuthenticates() async {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "iveta@minitbakery.com"
        vm.password = "password"
        vm.otpCode = "5678"

        vm.confirmVerification(purpose: .signIn)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(vm.state.authData)
    }

    func testConfirmVerificationPasswordResetSignalsPasswordResetCompleted() async {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "iveta@minitbakery.com"
        vm.otpCode = "9999"
        vm.path = [.verificationCode(.passwordReset)]

        vm.confirmVerification(purpose: .passwordReset)

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(vm.passwordResetCompleted)
        XCTAssertEqual(vm.path, [.verificationCode(.passwordReset)])
        XCTAssertNil(vm.state.authData)
        XCTAssertEqual(vm.state, .idle)
    }

    func testResendCodeRestartsCountdownWhenAllowed() async {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "iveta@minitbakery.com"
        vm.resendCountdownSeconds = 0
        vm.otpCode = "1234"

        vm.resendCode()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.otpCode, "")
        XCTAssertEqual(vm.resendCountdownSeconds, 104)
        XCTAssertFalse(vm.canResendCode)
    }

    func testResendCodeNoOpsWhileCountdownActive() async {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "iveta@minitbakery.com"
        vm.onVerificationScreenAppeared()

        vm.resendCode()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.resendCountdownSeconds, 104)
    }

    func testSubmitForgotPasswordEmailWithEmptyEmailSetsErrorMessage() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.submitForgotPasswordEmail()

        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testSubmitForgotPasswordEmailWithInvalidEmailSetsErrorMessage() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "user@domain"

        vm.submitForgotPasswordEmail()

        XCTAssertEqual(
            vm.errorMessage,
            String(localized: "login.error.invalidEmail", bundle: .module)
        )
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testSubmitForgotPasswordEmailPushesVerificationCode() async {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.email = "iveta@minitbakery.com"

        vm.submitForgotPasswordEmail()

        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.path, [.verificationCode(.passwordReset)])
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(vm.state, .idle)
    }

    func testContinueFromEmailFailureSetsErrorAndDoesNotNavigate() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "iveta@minitbakery.com"

        vm.continueFromEmail()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))
        XCTAssertEqual(vm.errorMessage, MockFailure.expected.errorDescription)
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testSubmitCreateAccountFailureSetsErrorAndDoesNotNavigate() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "new@minit.com"
        vm.password = "password"
        vm.confirmPassword = "password"

        vm.submitCreateAccount()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))
        XCTAssertEqual(vm.errorMessage, MockFailure.expected.errorDescription)
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testSubmitSignInFailureSetsErrorAndDoesNotNavigate() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "iveta@minitbakery.com"
        vm.password = "password"

        vm.submitSignIn()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))
        XCTAssertEqual(vm.errorMessage, MockFailure.expected.errorDescription)
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testSubmitForgotPasswordFailureSetsErrorAndDoesNotNavigate() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "iveta@minitbakery.com"

        vm.submitForgotPasswordEmail()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))
        XCTAssertEqual(vm.errorMessage, MockFailure.expected.errorDescription)
        XCTAssertTrue(vm.path.isEmpty)
    }

    func testResendCodeFailureSetsErrorWithoutRestartingCountdown() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "iveta@minitbakery.com"
        vm.otpCode = "1234"
        vm.resendCountdownSeconds = 0

        vm.resendCode()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))
        XCTAssertEqual(vm.errorMessage, MockFailure.expected.errorDescription)
        XCTAssertEqual(vm.otpCode, "1234")
        XCTAssertEqual(vm.resendCountdownSeconds, 0)
    }

    func testConfirmSignUpFailureSetsErrorWithoutAuthenticating() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "new@minit.com"
        vm.password = "password"
        vm.otpCode = "1234"

        vm.confirmVerification(purpose: .signUp)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))
        XCTAssertEqual(vm.errorMessage, MockFailure.expected.errorDescription)
        XCTAssertNil(vm.state.authData)
    }

    func testConfirmSignInFailureSetsErrorWithoutAuthenticating() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "iveta@minitbakery.com"
        vm.password = "password"
        vm.otpCode = "1234"

        vm.confirmVerification(purpose: .signIn)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))
        XCTAssertEqual(vm.errorMessage, MockFailure.expected.errorDescription)
        XCTAssertNil(vm.state.authData)
    }

    func testConfirmPasswordResetFailureSetsErrorWithoutCompletingReset() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "iveta@minitbakery.com"
        vm.otpCode = "1234"

        vm.confirmVerification(purpose: .passwordReset)
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))
        XCTAssertEqual(vm.errorMessage, MockFailure.expected.errorDescription)
        XCTAssertFalse(vm.passwordResetCompleted)
    }

    func testClearErrorResetsErrorMessageToNil() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())
        vm.login()
        XCTAssertNotNil(vm.errorMessage, "Precondition: login with empty fields should set an error")

        vm.clearError()

        XCTAssertNil(vm.errorMessage)
    }

    func testClearErrorIsANoOpWhenThereIsNoError() {
        let vm = LoginViewModel(authRepository: MockAuthRepository())

        vm.clearError()

        XCTAssertNil(vm.errorMessage)
    }

    func testClearErrorResetsErrorStateToIdle() async {
        let mockRepo = MockAuthRepository()
        mockRepo.errorToThrow = MockFailure.expected
        let vm = LoginViewModel(authRepository: mockRepo)
        vm.email = "iveta@minitbakery.com"

        vm.continueFromEmail()
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(vm.state, .error(MockFailure.expected.errorDescription!))

        vm.clearError()

        XCTAssertEqual(vm.state, .idle)
        XCTAssertNil(vm.errorMessage)
    }
}

// MARK: - Mock

private enum MockFailure: LocalizedError {
    case expected

    var errorDescription: String? { "Expected repository failure" }
}

private final class MockAuthRepository: AuthRepository, @unchecked Sendable {
    var shouldThrow = false
    var errorToThrow: Error?
    var logoutCalled = false
    var checkEmailExistsResult = true

    func login(email: String, password: String) async throws -> AuthData {
        if let errorToThrow { throw errorToThrow }
        if shouldThrow { throw NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Login failed"]) }
        return AuthData(token: "mock-token", userId: "mock-user")
    }

    func logout() async { logoutCalled = true }
    func currentSession() async throws -> AuthData? { nil }

    func checkEmailExists(email: String) async throws -> Bool {
        if let errorToThrow { throw errorToThrow }
        if shouldThrow { throw NSError(domain: "test", code: 0) }
        return checkEmailExistsResult
    }

    func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthData {
        if let errorToThrow { throw errorToThrow }
        if shouldThrow { throw NSError(domain: "test", code: 0) }
        return AuthData(token: "mock-token", userId: "mock-user")
    }

    func sendVerificationCode(email: String) async throws {
        if let errorToThrow { throw errorToThrow }
        if shouldThrow { throw NSError(domain: "test", code: 0) }
    }

    func confirmPasswordReset(email: String, code: String) async throws {
        if let errorToThrow { throw errorToThrow }
        if shouldThrow { throw NSError(domain: "test", code: 0) }
    }
}

@MainActor
private final class TestAppLanguagePreferenceStore: AppLanguagePreferenceStoring {
    var languageCode: String?
}

private extension LoginViewModel {
    convenience init(authRepository: MockAuthRepository) {
        self.init(
            authRepository: authRepository as any AuthRepository,
            appLanguagePreference: TestAppLanguagePreferenceStore()
        )
    }
}
