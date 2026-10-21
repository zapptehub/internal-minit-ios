import Observation
import Foundation
import DataAuth
import DataLoyaltyCard
import FeatureOnboarding

/// Root post-launch flow, replacing `ContentView`'s old `isAuthenticated` boolean.
///
/// Two durable decisions per launch:
/// 1. Is there a valid session? — via `AuthRepository.currentSession()` (Task 3.4's
///    restore-from-Firebase path, not an in-memory flag).
/// 2. Is onboarding already complete? — via `LoyaltyCardRepository.fetchLinkedCard`
///    (matrix: root checks for a linked card and skips onboarding when one exists).
///
/// Incomplete authenticated users mount `FeatureOnboarding`; already-linked users go
/// straight to `.authenticated` without ever showing create/claim success chrome.
/// Thrown errors from either check are distinct from confirmed "no session" / "no
/// card" (`nil`) so the UI can offer Retry instead of guessing.
///
/// Both lookups also have a deadline. Firebase Auth `getIDToken()` waits on a
/// secure-token request when the cached token is missing or near expiry, and
/// Realtime Database `getData()` only fails quickly when the connection is
/// already down. A get that was marked sent, or an ID-token refresh, does not
/// throw while the network never answers. Android's `Query.get()` does not
/// fail at all in that case. The deadline turns that hang into the existing
/// retry screens.
///
/// Cancellation is the same kind of failure. SwiftUI can cancel `bootstrap()`'s
/// `.task` — or the linked-card check inside it — without starting another
/// attempt, and returning early used to leave the UI on `.loading`. A cancelled
/// bootstrap shows `.sessionRestoreFailed`; a cancelled post-auth check shows
/// `.onboardingStatusFailed`. Either write is skipped when a newer bootstrap,
/// login, logout, or retry has already taken over.
///
/// Follows the same convention as `OnboardingViewModel`/`LoginViewModel`: public
/// methods are synchronous and dispatch their own `Task` internally, except
/// `bootstrap()` itself, which the presenting view drives from `.task { }`.
@MainActor
@Observable
final class AppFlowViewModel {
    static let defaultRestoreTimeout: Duration = .seconds(15)
    enum State: Equatable {
        case loading
        /// `currentSession()` threw — validity couldn't be determined (e.g. offline),
        /// not a confirmed logged-out state.
        case sessionRestoreFailed
        /// Session exists but `fetchLinkedCard` threw — completion status unknown.
        /// Carries `userId` so Retry can re-check the card without re-running session
        /// restore.
        case onboardingStatusFailed(userId: String)
        case unauthenticated
        case onboarding(userId: String)
        case authenticated(userId: String)
    }

    private(set) var state: State = .loading
    /// Snapshot taken once, right before mounting `FeatureOnboarding`, from whatever
    /// language a locally persisted onboarding checkpoint carries — restores the
    /// last-selected in-progress language immediately. `nil` on first launch, when
    /// already complete (progress was cleared), or when nothing was stored yet.
    private(set) var restoredLocale: Locale?

    private let authRepository: AuthRepository
    private let loyaltyCardRepository: LoyaltyCardRepository
    private let onboardingProgressStore: any OnboardingProgressStoring
    private let restoreTimeout: Duration
    /// Drops avatar responses stored on the network session. The app passes
    /// `NetworkClientImpl.clearCachedResponses()`. That cache is the session's
    /// own, not `URLCache.shared`.
    private let clearAvatarURLCache: @MainActor () -> Void
    /// Identifies the newest bootstrap, login, logout, or retry. An older attempt
    /// applies a result — including after cancellation — only while this still matches.
    private var launchAttempt = 0

    init(
        authRepository: AuthRepository,
        loyaltyCardRepository: LoyaltyCardRepository,
        onboardingProgressStore: any OnboardingProgressStoring,
        restoreTimeout: Duration = AppFlowViewModel.defaultRestoreTimeout,
        clearAvatarURLCache: @escaping @MainActor () -> Void = {}
    ) {
        self.authRepository = authRepository
        self.loyaltyCardRepository = loyaltyCardRepository
        self.onboardingProgressStore = onboardingProgressStore
        self.restoreTimeout = restoreTimeout
        self.clearAvatarURLCache = clearAvatarURLCache
    }

    /// Called once from `ContentView`'s `.task { }`.
    func bootstrap() async {
        let attempt = beginLaunchAttempt()
        state = .loading
        do {
            if let session = try await withLaunchTimeout({
                try await self.authRepository.currentSession()
            }) {
                guard isCurrentLaunchAttempt(attempt) else { return }
                await resolvePostAuthDestination(userId: session.userId, attempt: attempt)
            } else {
                guard isCurrentLaunchAttempt(attempt) else { return }
                restoredLocale = nil
                state = .unauthenticated
            }
        } catch is CancellationError {
            applySessionRestoreFailureIfCurrent(attempt)
        } catch {
            applySessionRestoreFailureIfCurrent(attempt)
        }
    }

    func retryBootstrap() {
        switch state {
        case .sessionRestoreFailed:
            Task { await bootstrap() }
        case .onboardingStatusFailed(let userId):
            let attempt = beginLaunchAttempt()
            state = .loading
            Task { await resolvePostAuthDestination(userId: userId, attempt: attempt) }
        default:
            break
        }
    }

    /// `FeatureLogin.createScreen`'s `onLoginSuccess` callback already hands back the
    /// freshly authenticated `AuthData` — reuse it directly instead of re-invoking
    /// `currentSession()` a second time right after login just wrote it. Still runs
    /// the linked-card check so a returning account that already finished onboarding
    /// skips straight into the main app.
    func didLogIn(_ session: AuthData) {
        let attempt = beginLaunchAttempt()
        state = .loading
        Task { await resolvePostAuthDestination(userId: session.userId, attempt: attempt) }
    }

    /// `FeatureOnboarding`'s `onCompleted` callback — fires only after the terminal
    /// primary is tapped with a confirmed linked card (Create Card's Continue, or
    /// processing scan's Enter Minit), never from bootstrap.
    func didCompleteOnboarding(userId: String) {
        restoredLocale = nil
        state = .authenticated(userId: userId)
    }

    /// Signs the user out and returns them to the unauthenticated flow (e.g. from the
    /// dashboard-under-construction placeholder's Log Out button).
    ///
    /// Clears the session URL cache before the auth call, the same moment Home
    /// confirms logout, and again after `logout()` returns. A load in flight can
    /// refill the cache during that call. A later account must not reuse a private
    /// avatar response. Every account still receives `avatars/default.webp`.
    func logOut() {
        let attempt = beginLaunchAttempt()
        clearAvatarURLCache()
        Task {
            await authRepository.logout()
            guard isCurrentLaunchAttempt(attempt) else { return }
            // Inside the guard, before `.unauthenticated` is published. A newer
            // launch owns the cache once this attempt is stale. A load can refill
            // it during logout(), after the clear above.
            clearAvatarURLCache()
            restoredLocale = nil
            state = .unauthenticated
        }
    }

    /// Routes a known-authenticated `userId` based on whether a loyalty card is already
    /// linked: skip onboarding when complete, otherwise mount the flow (and restore any
    /// mid-onboarding locale checkpoint).
    private func resolvePostAuthDestination(userId: String, attempt: Int) async {
        do {
            let linkedCard = try await withLaunchTimeout {
                try await self.loyaltyCardRepository.fetchLinkedCard(userId: userId)
            }
            guard isCurrentLaunchAttempt(attempt) else { return }
            if linkedCard != nil {
                restoredLocale = nil
                state = .authenticated(userId: userId)
                return
            }

            let persistedLanguage = try? onboardingProgressStore.load(userId: userId)?.language
            restoredLocale = persistedLanguage.map { Locale(identifier: $0.rawValue) }
            state = .onboarding(userId: userId)
        } catch is CancellationError {
            applyOnboardingStatusFailureIfCurrent(attempt, userId: userId)
        } catch {
            applyOnboardingStatusFailureIfCurrent(attempt, userId: userId)
        }
    }

    private func beginLaunchAttempt() -> Int {
        launchAttempt += 1
        return launchAttempt
    }

    private func isCurrentLaunchAttempt(_ attempt: Int) -> Bool {
        attempt == launchAttempt
    }

    private func applySessionRestoreFailureIfCurrent(_ attempt: Int) {
        guard isCurrentLaunchAttempt(attempt) else { return }
        state = .sessionRestoreFailed
    }

    private func applyOnboardingStatusFailureIfCurrent(_ attempt: Int, userId: String) {
        guard isCurrentLaunchAttempt(attempt) else { return }
        state = .onboardingStatusFailed(userId: userId)
    }

    /// Runs `operation` until it finishes or `restoreTimeout` elapses.
    ///
    /// The caller resumes on timeout without waiting for `operation`. Firebase's
    /// token and `getData` callbacks are not cancellation-cooperative, so a task
    /// group would stay suspended on the hung call and the launch screen would
    /// not appear.
    private func withLaunchTimeout<T: Sendable>(
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        let gate = LaunchTimeoutGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let operationTask = Task {
                    do {
                        let value = try await operation()
                        gate.resume(continuation, with: .success(value))
                    } catch {
                        gate.resume(continuation, with: .failure(error))
                    }
                }
                let timeoutTask = Task {
                    do {
                        try await Task.sleep(for: restoreTimeout)
                        gate.resume(continuation, with: .failure(LaunchRestoreTimeout()))
                    } catch {
                        gate.resume(continuation, with: .failure(error))
                    }
                }
                gate.track(operationTask)
                gate.track(timeoutTask)
            }
        } onCancel: {
            gate.cancelTrackedTasks()
        }
    }
}

/// One resume of the launch-timeout continuation, then cancellation of the other task.
private final class LaunchTimeoutGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false
    private var cancelled = false
    private var tasks: [Task<Void, Never>] = []

    func track(_ task: Task<Void, Never>) {
        lock.lock()
        tasks.append(task)
        let shouldCancel = cancelled
        lock.unlock()
        if shouldCancel {
            task.cancel()
        }
    }

    func cancelTrackedTasks() {
        lock.lock()
        cancelled = true
        let pending = tasks
        lock.unlock()
        pending.forEach { $0.cancel() }
    }

    func resume<T>(
        _ continuation: CheckedContinuation<T, Error>,
        with result: Result<T, Error>
    ) {
        lock.lock()
        let shouldResume = !didResume
        if shouldResume {
            didResume = true
        }
        let pending = tasks
        lock.unlock()
        guard shouldResume else { return }
        pending.forEach { $0.cancel() }
        continuation.resume(with: result)
    }
}

private struct LaunchRestoreTimeout: Error {}
