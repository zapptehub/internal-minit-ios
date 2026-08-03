import XCTest
import DataAuth
import DataLoyaltyCard
import FeatureOnboarding
@testable import minit

@MainActor
final class AppFlowViewModelTests: XCTestCase {
    private func makeViewModel(
        auth: FakeAuthRepository = FakeAuthRepository(),
        loyalty: FakeLoyaltyCardRepository = FakeLoyaltyCardRepository(),
        progress: FakeOnboardingProgressStore? = nil
    ) -> AppFlowViewModel {
        AppFlowViewModel(
            authRepository: auth,
            loyaltyCardRepository: loyalty,
            onboardingProgressStore: progress ?? FakeOnboardingProgressStore()
        )
    }

    private func settle() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    // MARK: Session restore

    func testBootstrapWithNoSessionGoesUnauthenticated() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = nil
        let vm = makeViewModel(auth: auth)

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .unauthenticated)
        XCTAssertNil(vm.restoredLocale)
    }

    func testBootstrapWhenSessionRestoreThrowsGoesSessionRestoreFailed() async {
        let auth = FakeAuthRepository()
        auth.errorToThrow = TestError.network
        let vm = makeViewModel(auth: auth)

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .sessionRestoreFailed)
    }

    func testRetryBootstrapFromSessionRestoreFailedReRunsBootstrap() async {
        let auth = FakeAuthRepository()
        auth.errorToThrow = TestError.network
        let vm = makeViewModel(auth: auth)
        await vm.bootstrap()
        XCTAssertEqual(vm.state, .sessionRestoreFailed)

        auth.errorToThrow = nil
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        vm.retryBootstrap()
        await settle()

        XCTAssertEqual(vm.state, .onboarding(userId: "user-1"))
    }

    /// Revoked / no-longer-valid sessions surface as `currentSession() == nil`
    /// (see `AuthSessionErrorClassifier` + `FirebaseAuthApiImpl.restoreSession`).
    func testBootstrapTreatsRevokedSessionAsUnauthenticated() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = nil
        let vm = makeViewModel(auth: auth)

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .unauthenticated)
    }

    // MARK: Linked-card completion gate

    func testBootstrapWithSessionAndLinkedCardSkipsOnboarding() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.linkedCard = LoyaltyCardData(code: "MINIT-1", ownerUserId: "user-1", points: 10)
        let vm = makeViewModel(auth: auth, loyalty: loyalty)

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .authenticated)
        XCTAssertNil(vm.restoredLocale)
    }

    func testBootstrapWithSessionAndNoCardMountsOnboarding() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        let vm = makeViewModel(auth: auth)

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .onboarding(userId: "user-1"))
    }

    func testBootstrapRestoresLocaleFromProgressWhenIncomplete() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        let progress = FakeOnboardingProgressStore()
        try? progress.save(OnboardingProgress(step: .language, language: .sk), userId: "user-1")
        let vm = makeViewModel(auth: auth, progress: progress)

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .onboarding(userId: "user-1"))
        XCTAssertEqual(vm.restoredLocale?.identifier, "sk")
    }

    func testBootstrapWhenFetchLinkedCardThrowsGoesOnboardingStatusFailed() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.fetchLinkedCardErrorToThrow = TestError.network
        let vm = makeViewModel(auth: auth, loyalty: loyalty)

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .onboardingStatusFailed(userId: "user-1"))
    }

    func testRetryBootstrapFromOnboardingStatusFailedReChecksLinkedCard() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.fetchLinkedCardErrorToThrow = TestError.network
        let vm = makeViewModel(auth: auth, loyalty: loyalty)
        await vm.bootstrap()
        XCTAssertEqual(vm.state, .onboardingStatusFailed(userId: "user-1"))

        loyalty.fetchLinkedCardErrorToThrow = nil
        loyalty.linkedCard = LoyaltyCardData(code: "MINIT-1", ownerUserId: "user-1", points: 0)
        vm.retryBootstrap()
        await settle()

        XCTAssertEqual(vm.state, .authenticated)
        XCTAssertEqual(auth.currentSessionCallCount, 1, "Retry should not re-hit session restore")
    }

    // MARK: Login / in-flow completion

    func testDidLogInWithLinkedCardSkipsOnboarding() async {
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.linkedCard = LoyaltyCardData(code: "MINIT-1", ownerUserId: "user-1", points: 0)
        let vm = makeViewModel(loyalty: loyalty)

        vm.didLogIn(AuthData(token: "t", userId: "user-1"))
        await settle()

        XCTAssertEqual(vm.state, .authenticated)
    }

    func testDidLogInWithoutCardMountsOnboarding() async {
        let vm = makeViewModel()

        vm.didLogIn(AuthData(token: "t", userId: "user-2"))
        await settle()

        XCTAssertEqual(vm.state, .onboarding(userId: "user-2"))
    }

    func testDidLogInWhenCardLookupFailsShowsRetryableOnboardingStatusFailure() async {
        let auth = FakeAuthRepository()
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.fetchLinkedCardErrorToThrow = TestError.network
        let vm = makeViewModel(auth: auth, loyalty: loyalty)

        vm.didLogIn(AuthData(token: "t", userId: "user-2"))
        await settle()

        XCTAssertEqual(vm.state, .onboardingStatusFailed(userId: "user-2"))
        XCTAssertEqual(
            auth.currentSessionCallCount,
            0,
            "Post-login routing must use the supplied session instead of restoring it again"
        )
    }

    func testDidCompleteOnboardingEntersAuthenticated() {
        let vm = makeViewModel()
        vm.didCompleteOnboarding()
        XCTAssertEqual(vm.state, .authenticated)
        XCTAssertNil(vm.restoredLocale)
    }

    func testLogOutCallsRepositoryAndReturnsUnauthenticated() async {
        let auth = FakeAuthRepository()
        let vm = makeViewModel(auth: auth)
        vm.didCompleteOnboarding()
        XCTAssertEqual(vm.state, .authenticated)

        vm.logOut()
        await settle()

        XCTAssertEqual(vm.state, .unauthenticated)
        XCTAssertEqual(auth.logoutCallCount, 1)
        XCTAssertNil(vm.restoredLocale)
    }
}

// MARK: - Fakes

private enum TestError: Error {
    case network
}

private final class FakeAuthRepository: AuthRepository, @unchecked Sendable {
    var sessionToReturn: AuthData?
    var errorToThrow: Error?
    private(set) var currentSessionCallCount = 0
    private(set) var logoutCallCount = 0

    func login(email: String, password: String) async throws -> AuthData {
        AuthData(token: "t", userId: "user")
    }

    func logout() async {
        logoutCallCount += 1
    }

    func currentSession() async throws -> AuthData? {
        currentSessionCallCount += 1
        if let errorToThrow { throw errorToThrow }
        return sessionToReturn
    }

    func checkEmailExists(email: String) async throws -> Bool { false }
    func register(email: String, password: String, marketingOptIn: Bool) async throws -> AuthData {
        AuthData(token: "t", userId: "user")
    }
    func sendVerificationCode(email: String) async throws {}
    func confirmPasswordReset(email: String, code: String) async throws {}
}

private final class FakeLoyaltyCardRepository: LoyaltyCardRepository, @unchecked Sendable {
    var linkedCard: LoyaltyCardData?
    var fetchLinkedCardErrorToThrow: Error?

    func createCard(userId: String) async throws -> LoyaltyCardData {
        LoyaltyCardData(code: "NEW", ownerUserId: userId, points: 0)
    }

    func claimCard(userId: String, code: String) async throws -> LoyaltyCardData {
        LoyaltyCardData(code: code, ownerUserId: userId, points: 0)
    }

    func fetchLinkedCard(userId: String) async throws -> LoyaltyCardData? {
        if let fetchLinkedCardErrorToThrow { throw fetchLinkedCardErrorToThrow }
        return linkedCard
    }
}

@MainActor
private final class FakeOnboardingProgressStore: OnboardingProgressStoring {
    private var progressByUserId: [String: OnboardingProgress] = [:]

    func load(userId: String) throws -> OnboardingProgress? {
        progressByUserId[userId]
    }

    func save(_ progress: OnboardingProgress, userId: String) throws {
        progressByUserId[userId] = progress
    }

    func clear(userId: String) {
        progressByUserId[userId] = nil
    }
}
