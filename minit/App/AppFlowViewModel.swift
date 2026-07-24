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
/// Follows the same convention as `OnboardingViewModel`/`LoginViewModel`: public
/// methods are synchronous and dispatch their own `Task` internally, except
/// `bootstrap()` itself, which the presenting view drives from `.task { }`.
@MainActor
@Observable
final class AppFlowViewModel {
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
        case authenticated
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

    init(
        authRepository: AuthRepository,
        loyaltyCardRepository: LoyaltyCardRepository,
        onboardingProgressStore: any OnboardingProgressStoring
    ) {
        self.authRepository = authRepository
        self.loyaltyCardRepository = loyaltyCardRepository
        self.onboardingProgressStore = onboardingProgressStore
    }

    /// Called once from `ContentView`'s `.task { }`.
    func bootstrap() async {
        state = .loading
        do {
            if let session = try await authRepository.currentSession() {
                await resolvePostAuthDestination(userId: session.userId)
            } else {
                restoredLocale = nil
                state = .unauthenticated
            }
        } catch {
            state = .sessionRestoreFailed
        }
    }

    func retryBootstrap() {
        switch state {
        case .sessionRestoreFailed:
            Task { await bootstrap() }
        case .onboardingStatusFailed(let userId):
            Task {
                state = .loading
                await resolvePostAuthDestination(userId: userId)
            }
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
        state = .loading
        Task { await resolvePostAuthDestination(userId: session.userId) }
    }

    /// `FeatureOnboarding`'s `onCompleted` callback — fires only after "Enter Minit" is
    /// tapped with a confirmed linked card (in-flow completion), never from bootstrap.
    func didCompleteOnboarding() {
        restoredLocale = nil
        state = .authenticated
    }

    /// Routes a known-authenticated `userId` based on whether a loyalty card is already
    /// linked: skip onboarding when complete, otherwise mount the flow (and restore any
    /// mid-onboarding locale checkpoint).
    private func resolvePostAuthDestination(userId: String) async {
        do {
            if try await loyaltyCardRepository.fetchLinkedCard(userId: userId) != nil {
                restoredLocale = nil
                state = .authenticated
                return
            }

            let persistedLanguage = try? onboardingProgressStore.load(userId: userId)?.language
            restoredLocale = persistedLanguage.map { Locale(identifier: $0.rawValue) }
            state = .onboarding(userId: userId)
        } catch {
            state = .onboardingStatusFailed(userId: userId)
        }
    }
}
