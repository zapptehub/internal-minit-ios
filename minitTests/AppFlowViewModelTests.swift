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
        progress: FakeOnboardingProgressStore? = nil,
        restoreTimeout: Duration = AppFlowViewModel.defaultRestoreTimeout
    ) -> AppFlowViewModel {
        AppFlowViewModel(
            authRepository: auth,
            loyaltyCardRepository: loyalty,
            onboardingProgressStore: progress ?? FakeOnboardingProgressStore(),
            restoreTimeout: restoreTimeout
        )
    }

    private func settle() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    /// Polls until `viewModel.state` equals `expected`, or until `timeout` elapses.
    /// Callers assert the state afterward so a missed deadline fails the test.
    private func waitForState(
        _ viewModel: AppFlowViewModel,
        _ expected: AppFlowViewModel.State,
        timeout: Duration = .seconds(2)
    ) async {
        await waitUntil(timeout: timeout) { viewModel.state == expected }
    }

    /// Polls until `condition` is true, or until `timeout` elapses.
    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
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

    /// Firebase session restore can suspend until the network returns. The
    /// fake never returns, so this fails if the deadline waits on that call.
    func testBootstrapWhenSessionRestoreNeverReturnsFailsAfterTimeout() async {
        XCTAssertEqual(AppFlowViewModel.defaultRestoreTimeout, .seconds(15))
        let auth = FakeAuthRepository()
        auth.hangCurrentSession = true
        let vm = makeViewModel(auth: auth, restoreTimeout: .milliseconds(50))

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .sessionRestoreFailed)
        XCTAssertEqual(auth.currentSessionCallCount, 1)
    }

    func testRetryAfterHungSessionRestoreRunsBootstrapAgain() async {
        let auth = FakeAuthRepository()
        auth.hangCurrentSession = true
        let vm = makeViewModel(auth: auth, restoreTimeout: .milliseconds(50))
        await vm.bootstrap()
        XCTAssertEqual(vm.state, .sessionRestoreFailed)

        auth.hangCurrentSession = false
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        vm.retryBootstrap()
        await waitForState(vm, .onboarding(userId: "user-1"))

        XCTAssertEqual(vm.state, .onboarding(userId: "user-1"))
        XCTAssertEqual(auth.currentSessionCallCount, 2)
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

        XCTAssertEqual(vm.state, .authenticated(userId: "user-1"))
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

    func testBootstrapWhenLinkedCardFetchNeverReturnsFailsAfterTimeout() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.hangFetchLinkedCard = true
        let vm = makeViewModel(auth: auth, loyalty: loyalty, restoreTimeout: .milliseconds(50))

        await vm.bootstrap()

        XCTAssertEqual(vm.state, .onboardingStatusFailed(userId: "user-1"))
        XCTAssertEqual(auth.currentSessionCallCount, 1)
    }

    func testDidLogInWhenLinkedCardFetchNeverReturnsFailsAfterTimeout() async {
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.hangFetchLinkedCard = true
        let vm = makeViewModel(loyalty: loyalty, restoreTimeout: .milliseconds(50))

        vm.didLogIn(AuthData(token: "t", userId: "user-2"))
        await waitForState(vm, .onboardingStatusFailed(userId: "user-2"))

        XCTAssertEqual(vm.state, .onboardingStatusFailed(userId: "user-2"))
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

        XCTAssertEqual(vm.state, .authenticated(userId: "user-1"))
        XCTAssertEqual(auth.currentSessionCallCount, 1, "Retry should not re-hit session restore")
    }

    // MARK: Login / in-flow completion

    func testDidLogInWithLinkedCardSkipsOnboarding() async {
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.linkedCard = LoyaltyCardData(code: "MINIT-1", ownerUserId: "user-1", points: 0)
        let vm = makeViewModel(loyalty: loyalty)

        vm.didLogIn(AuthData(token: "t", userId: "user-1"))
        await settle()

        XCTAssertEqual(vm.state, .authenticated(userId: "user-1"))
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
        vm.didCompleteOnboarding(userId: "user-1")
        XCTAssertEqual(vm.state, .authenticated(userId: "user-1"))
        XCTAssertNil(vm.restoredLocale)
    }

    func testLogOutCallsRepositoryAndReturnsUnauthenticated() async {
        let auth = FakeAuthRepository()
        let vm = makeViewModel(auth: auth)
        vm.didCompleteOnboarding(userId: "user-1")
        XCTAssertEqual(vm.state, .authenticated(userId: "user-1"))

        vm.logOut()
        await settle()

        XCTAssertEqual(vm.state, .unauthenticated)
        XCTAssertEqual(auth.logoutCallCount, 1)
        XCTAssertNil(vm.restoredLocale)
    }

    // MARK: Cancellation

    func testCancelledBootstrapGoesSessionRestoreFailed() async {
        let auth = FakeAuthRepository()
        auth.hangCurrentSession = true
        let vm = makeViewModel(auth: auth)
        let finished = AttemptFinished()
        let task = Task {
            await vm.bootstrap()
            finished.markFinished()
        }
        await waitUntil { auth.currentSessionCallCount >= 1 }
        XCTAssertGreaterThanOrEqual(auth.currentSessionCallCount, 1)

        task.cancel()
        await waitUntil { finished.isFinished }
        await waitForState(vm, .sessionRestoreFailed)

        XCTAssertTrue(finished.isFinished)
        XCTAssertEqual(vm.state, .sessionRestoreFailed)
    }

    func testCancelledPostAuthCheckGoesOnboardingStatusFailed() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.hangFetchLinkedCard = true
        let vm = makeViewModel(auth: auth, loyalty: loyalty)
        let finished = AttemptFinished()
        let task = Task {
            await vm.bootstrap()
            finished.markFinished()
        }
        await waitUntil { loyalty.fetchLinkedCardCallCount >= 1 }
        XCTAssertGreaterThanOrEqual(loyalty.fetchLinkedCardCallCount, 1)

        task.cancel()
        await waitUntil { finished.isFinished }
        await waitForState(vm, .onboardingStatusFailed(userId: "user-1"))

        XCTAssertTrue(finished.isFinished)
        XCTAssertEqual(vm.state, .onboardingStatusFailed(userId: "user-1"))
    }

    /// A newer `bootstrap()` is also what Retry starts after a session-restore failure.
    func testCancelledOlderBootstrapKeepsInFlightNewerAttempt() async {
        let auth = FakeAuthRepository()
        auth.hangCurrentSession = true
        let vm = makeViewModel(auth: auth)
        let olderFinished = AttemptFinished()
        let newerFinished = AttemptFinished()
        let older = Task {
            await vm.bootstrap()
            olderFinished.markFinished()
        }
        await waitUntil { auth.currentSessionCallCount >= 1 }
        XCTAssertGreaterThanOrEqual(auth.currentSessionCallCount, 1)

        let newer = Task {
            await vm.bootstrap()
            newerFinished.markFinished()
        }
        await waitUntil { auth.currentSessionCallCount >= 2 }
        XCTAssertGreaterThanOrEqual(auth.currentSessionCallCount, 2)
        XCTAssertEqual(vm.state, .loading)

        older.cancel()
        await waitUntil { olderFinished.isFinished }
        await waitForState(vm, .loading)

        XCTAssertTrue(olderFinished.isFinished)
        XCTAssertEqual(vm.state, .loading)

        newer.cancel()
        await waitUntil { newerFinished.isFinished }
        await waitForState(vm, .sessionRestoreFailed)
        XCTAssertTrue(newerFinished.isFinished)
        XCTAssertEqual(vm.state, .sessionRestoreFailed)
    }

    func testCancelledOlderPostAuthCheckKeepsFinishedLogin() async {
        let auth = FakeAuthRepository()
        auth.sessionToReturn = AuthData(token: "t", userId: "user-1")
        let loyalty = FakeLoyaltyCardRepository()
        loyalty.hangFetchLinkedCard = true
        let vm = makeViewModel(auth: auth, loyalty: loyalty)
        let olderFinished = AttemptFinished()
        let older = Task {
            await vm.bootstrap()
            olderFinished.markFinished()
        }
        await waitUntil { loyalty.fetchLinkedCardCallCount >= 1 }
        XCTAssertGreaterThanOrEqual(loyalty.fetchLinkedCardCallCount, 1)

        loyalty.hangFetchLinkedCard = false
        loyalty.linkedCard = LoyaltyCardData(code: "MINIT-2", ownerUserId: "user-2", points: 0)
        vm.didLogIn(AuthData(token: "t", userId: "user-2"))
        await waitForState(vm, .authenticated(userId: "user-2"))
        XCTAssertEqual(vm.state, .authenticated(userId: "user-2"))

        older.cancel()
        await waitUntil { olderFinished.isFinished }
        await waitForState(vm, .authenticated(userId: "user-2"))

        XCTAssertTrue(olderFinished.isFinished)
        XCTAssertEqual(vm.state, .authenticated(userId: "user-2"))
    }

    func testCancelledOlderBootstrapKeepsFinishedLogout() async {
        let auth = FakeAuthRepository()
        auth.hangCurrentSession = true
        let vm = makeViewModel(auth: auth)
        let olderFinished = AttemptFinished()
        let older = Task {
            await vm.bootstrap()
            olderFinished.markFinished()
        }
        await waitUntil { auth.currentSessionCallCount >= 1 }
        XCTAssertGreaterThanOrEqual(auth.currentSessionCallCount, 1)

        vm.logOut()
        await waitForState(vm, .unauthenticated)
        XCTAssertEqual(vm.state, .unauthenticated)

        older.cancel()
        await waitUntil { olderFinished.isFinished }
        await waitForState(vm, .unauthenticated)

        XCTAssertTrue(olderFinished.isFinished)
        XCTAssertEqual(vm.state, .unauthenticated)
    }
}

/// Stays suspended until the caller cancels. `Task.sleep` observes cancellation,
/// so this does not park a `CheckedContinuation` the runtime would report as leaked.
private func hangUntilCancelled() async throws {
    while !Task.isCancelled {
        try await Task.sleep(for: .seconds(3600))
    }
    throw CancellationError()
}

// MARK: - Fakes

private enum TestError: Error {
    case network
}

private final class FakeAuthRepository: AuthRepository, @unchecked Sendable {
    var sessionToReturn: AuthData?
    var errorToThrow: Error?
    var hangCurrentSession = false
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
        if hangCurrentSession {
            try await hangUntilCancelled()
        }
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
    var hangFetchLinkedCard = false
    private(set) var fetchLinkedCardCallCount = 0

    func createCard(userId: String) async throws -> LoyaltyCardData {
        LoyaltyCardData(code: "NEW", ownerUserId: userId, points: 0)
    }

    func claimCard(userId: String, code: String) async throws -> LoyaltyCardData {
        LoyaltyCardData(code: code, ownerUserId: userId, points: 0)
    }

    func fetchLinkedCard(userId: String) async throws -> LoyaltyCardData? {
        fetchLinkedCardCallCount += 1
        if hangFetchLinkedCard {
            try await hangUntilCancelled()
        }
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

/// Set on the main actor when a launch task's `bootstrap()` call has returned,
/// including after cancellation. Tests poll this instead of sleeping so a late
/// failure write is visible before the assertion.
private final class AttemptFinished: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func markFinished() {
        lock.lock()
        finished = true
        lock.unlock()
    }

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return finished
    }
}
