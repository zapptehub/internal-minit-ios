import Observation
import Foundation
import DataProfile
import DataLoyaltyCard
import CoreExtensions

/// Resumable onboarding state machine's core: shared state, lifecycle (bootstrap /
/// completion), and routing plumbing. What each *section* actually does lives in its
/// own file — `OnboardingViewModel+Name.swift`, `+Language.swift`,
/// `+LoyaltyDecision.swift`, `+CreateCard.swift`, `+Scanner.swift`, `+Claim.swift` —
/// and every interactive "what step comes next" decision lives in `OnboardingRouter`.
///
/// `step` is still assigned directly in three lifecycle paths that are not user
/// transitions: restoring a persisted checkpoint, corrupted-progress recovery, and
/// `complete(with:)`'s success-chrome landing. See `OnboardingRouter`'s doc comment.
///
/// Screens (Task 4.2–4.5) are expected to own this via `@State` the same way
/// `LoginFlowContainer` owns `LoginViewModel`, bind their controls to its published
/// state, and call its step-advancing methods directly from button actions — those
/// methods are synchronous and internally dispatch their own `Task`, mirroring
/// `LoginViewModel`, so call sites never need `Task { }` boilerplate.
@MainActor
@Observable
public final class OnboardingViewModel {
    public let userId: String

    public private(set) var step: OnboardingStep
    /// Set alongside every `advance(via:)` call — lets `OnboardingFlowScreen` pick a
    /// push-style (forward) or pop-style (backward) slide direction for the step
    /// content, matching `NavigationStack`'s own behavior.
    public private(set) var stepDirection: OnboardingStepDirection = .forward
    /// `true` while `bootstrap()` is resolving the linked-card check and local resume —
    /// screens should show a neutral loading state instead of any step content.
    public private(set) var isBootstrapping = true

    public var name: String = ""
    /// Source of truth for the onboarding UI's locale. Screens apply it via
    /// `.environment(\.locale, Locale(identifier: selectedLanguage.rawValue))`. Updated
    /// immediately on `selectLanguage(_:)` (per the matrix's "switches immediately on
    /// row tap") but only becomes durable — written to the progress store and the
    /// device-wide `appLanguagePreference` — once `continueFromLanguage()` runs.
    public internal(set) var selectedLanguage: OnboardingLanguageCode
    /// Row choice on the `loyaltyDecision` step. Not persisted until `continueFromLoyaltyDecision()`.
    public internal(set) var selectedBranch: OnboardingLoyaltyBranch?

    public internal(set) var isLoading = false
    /// Inline, non-alert error surfaced under a field (name entry, manual code entry).
    /// The system-alert failure cases (`createCardFailed`, `claimCardFailed`,
    /// `cameraPermissionDenied`, `bootstrapFetchFailed`) go through `activeAlert` instead.
    public var errorMessage: String?
    public internal(set) var activeAlert: OnboardingAlert?

    /// Set once `createCard`/`claimCard` confirms a linked card. The terminal screen's
    /// "Enter Minit" button should only be enabled while this is non-nil.
    public private(set) var linkedCard: LoyaltyCardData?

    /// Top progress-bar fill. Finish steps (create/claim) stay near-complete while
    /// the status card is loading, then jump to 100% once `linkedCard` is set.
    public var progressFraction: Double {
        step.progressFraction(isFinishComplete: linkedCard != nil)
    }

    let profileRepository: ProfileRepository
    let loyaltyCardRepository: LoyaltyCardRepository
    let progressStore: any OnboardingProgressStoring
    /// Device-wide (not account-scoped) language preference — read once at `init` to
    /// pre-select a returning device-owner's last confirmed language ahead of the
    /// device's own system-language guess, and written on `continueFromLanguage()` so
    /// it survives logout/re-login. See `AppLanguagePreferenceStoring`'s doc comment.
    let appLanguagePreference: any AppLanguagePreferenceStoring
    let analytics: OnboardingAnalyticsTracking
    private let onCompleted: () -> Void
    private let router = OnboardingRouter()

    /// Durable (persisted) language — distinct from `selectedLanguage` so an in-progress
    /// row tap that never reaches Continue doesn't overwrite what was last confirmed.
    var confirmedLanguage: OnboardingLanguageCode?
    /// Code + source of the most recent claim attempt, kept only so `retryClaimCard()`
    /// can safely reissue the same idempotent call without requiring another scan.
    var lastAttemptedCardCode: String?
    var lastClaimSource: OnboardingClaimSource?

    public init(
        userId: String,
        profileRepository: ProfileRepository,
        loyaltyCardRepository: LoyaltyCardRepository,
        progressStore: any OnboardingProgressStoring,
        appLanguagePreference: any AppLanguagePreferenceStoring,
        analytics: OnboardingAnalyticsTracking,
        preferredLanguages: [String] = Locale.preferredLanguages,
        onCompleted: @escaping () -> Void
    ) {
        self.userId = userId
        self.profileRepository = profileRepository
        self.loyaltyCardRepository = loyaltyCardRepository
        self.progressStore = progressStore
        self.appLanguagePreference = appLanguagePreference
        self.analytics = analytics
        self.onCompleted = onCompleted
        self.step = .name
        self.selectedLanguage = Self.initialLanguage(
            appLanguagePreference: appLanguagePreference,
            preferredLanguages: preferredLanguages
        )
    }

    // MARK: Routing

    public var canGoBack: Bool { router.canGoBack(from: step) }

    /// Single back entry point — the visual affordance differs per step (circular
    /// button, OS-alert cancel, dark scanner button) but the destination depends only
    /// on the current step, never on which control triggered it. See `OnboardingRouter`.
    /// Clears any active alert so a cancel-from-alert path cannot leave stale chrome
    /// on the destination step (e.g. camera-denied alert after returning to
    /// `loyaltyDecision`).
    public func goBack() {
        activeAlert = nil
        advance(via: .back)
    }

    /// Every section calls this instead of assigning `step` directly — keeps
    /// `OnboardingRouter` the single source of truth for interactive transitions and
    /// guarantees a checkpoint is always persisted alongside the move. Returns `false`
    /// (no-op) if `transition` is illegal from the current step.
    @discardableResult
    func advance(via transition: OnboardingRouter.Transition) -> Bool {
        guard let destination = router.nextStep(from: step, on: transition) else { return false }
        stepDirection = (transition == .back) ? .backward : .forward
        step = destination
        persistCheckpoint()
        return true
    }

    private func persistCheckpoint() {
        do {
            try progressStore.save(
                OnboardingProgress(step: step, language: confirmedLanguage),
                userId: userId
            )
        } catch {
            // Local checkpoint writes are best-effort; a write failure shouldn't block
            // navigation — worst case a relaunch re-resumes one step earlier.
        }
    }

    // MARK: Bootstrap / resume

    /// Called once from the presenting screen's `.task { }`. Resolves, in order: (1) a
    /// defensive "is a card already linked?" check that short-circuits straight to
    /// completion regardless of the persisted step — this covers both the matrix's
    /// explicit `creatingCard`/`processingScan` resume rule and any other stale-state edge
    /// case, since confirming a linked card is cheap and always safe to check first —
    /// then (2) restoring local progress, then (3) re-driving any step whose entry
    /// action is itself an idempotent backend call.
    public func bootstrap() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        do {
            if let existing = try await loyaltyCardRepository.fetchLinkedCard(userId: userId) {
                complete(with: existing)
                return
            }
        } catch {
            // Distinguish "no card" (nil) from "couldn't tell" (threw). Continuing into
            // create/claim on a transport failure risks racing an already-linked account.
            activeAlert = .bootstrapFetchFailed
            return
        }

        do {
            if let persisted = try progressStore.load(userId: userId) {
                apply(persisted: persisted)
            }
        } catch OnboardingProgressStoreError.corruptedData {
            // Can't trust the record — clear it and start over rather than get stuck
            // re-throwing on every subsequent launch.
            progressStore.clear(userId: userId)
            errorMessage = OnboardingLocalizedString.string(
                "onboarding.error.corruptedProgress",
                locale: Locale(identifier: selectedLanguage.rawValue)
            )
            step = .name
        } catch {
            step = .name
        }

        switch step {
        case .creatingCard:
            // Matrix: "silently re-invoke createCard() (auto-resumes processing)".
            performCreateCard()
        case .processingScan:
            selectedBranch = .existingCard
            advance(via: .unresumableProcessingScanFallback)
        default:
            break
        }
    }

    public func retryBootstrap() {
        guard !isBootstrapping else { return }
        activeAlert = nil
        errorMessage = nil
        analytics.trackRetryTapped(step: "bootstrap", file: #fileID)
        Task {
            await bootstrap()
        }
    }

    private func apply(persisted: OnboardingProgress) {
        confirmedLanguage = persisted.language
        if let confirmedLanguage {
            selectedLanguage = confirmedLanguage
        }

        guard let supportedStep = persisted.step.supportedStep else {
            // Unknown future step (older build resuming progress a newer build wrote).
            // Don't touch storage — a future relaunch on a build that understands it
            // should still see the original value — just render the earliest step.
            step = .name
            return
        }

        step = supportedStep
        analytics.trackOnboardingResumed(step: supportedStep.rawValue, file: #fileID)
    }

    // MARK: Completion

    func complete(with card: LoyaltyCardData) {
        linkedCard = card
        isLoading = false
        activeAlert = nil
        // Lifecycle exception (not an interactive transition): keep `creatingCard` /
        // `processingScan` so in-flow success chrome stays on the step that produced the
        // card. Any other step (bootstrap short-circuit while still on `.name`) lands
        // on `creatingCard` — the shared "card added successfully" presentation
        // screens bind to in Task 4.5. See `OnboardingRouter` doc for other
        // intentional direct `step` assignments.
        if step != .creatingCard && step != .processingScan {
            step = .creatingCard
        }
        progressStore.clear(userId: userId)
        analytics.trackOnboardingCompleted(file: #fileID)
    }

    /// "Enter Minit" on the terminal success screen — no-ops if completion hasn't
    /// actually been confirmed yet (defensive; the button itself should be disabled).
    public func tapEnterMinit() {
        guard linkedCard != nil else { return }
        analytics.trackEnterMinitTapped(file: #fileID)
        onCompleted()
    }

    // MARK: Shared helpers

    /// Debug/analytics-only categorization — never shown to the user, so it doesn't
    /// need localization the way `activeAlert`'s cases do. Shared by the CreateCard
    /// and Claim sections.
    static func analyticsReason(for error: Error) -> String {
        guard let loyaltyError = error as? LoyaltyCardError else {
            return "unknown:\(error.localizedDescription)"
        }
        switch loyaltyError {
        case .notFound: return "notFound"
        case .alreadyClaimed: return "alreadyClaimed"
        case .alreadyLinked: return "alreadyLinked"
        case .underlying(let message): return "underlying:\(message)"
        }
    }
}
