import XCTest
@testable import FeatureLogin
import DataAuth

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
}

// MARK: - Mock

private final class MockAuthRepository: AuthRepository {
    var shouldThrow = false
    var logoutCalled = false
    var checkEmailExistsResult = true

    func login(email: String, password: String) async throws -> AuthData {
        if shouldThrow { throw NSError(domain: "test", code: 0, userInfo: [NSLocalizedDescriptionKey: "Login failed"]) }
        return AuthData(token: "mock-token", userId: "mock-user")
    }

    func logout() async { logoutCalled = true }
    func currentSession() async throws -> AuthData? { nil }

    func checkEmailExists(email: String) async throws -> Bool {
        if shouldThrow { throw NSError(domain: "test", code: 0) }
        return checkEmailExistsResult
    }

    func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthData {
        if shouldThrow { throw NSError(domain: "test", code: 0) }
        return AuthData(token: "mock-token", userId: "mock-user")
    }

    func sendVerificationCode(email: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 0) }
    }

    func confirmPasswordReset(email: String, code: String) async throws {
        if shouldThrow { throw NSError(domain: "test", code: 0) }
    }
}
