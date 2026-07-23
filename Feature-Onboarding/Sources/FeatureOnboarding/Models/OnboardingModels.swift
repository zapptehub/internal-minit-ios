import Foundation

/// Resumable checkpoints owned by the onboarding feature.
///
/// Raw values are stored locally in account-scoped `UserDefaults`. Renaming an existing raw
/// value requires a local migration.
public enum OnboardingStep: String, Codable, Sendable, CaseIterable {
    case name
    case language
    case loyaltyDecision
    case creatingCard
    case scannerPermission
    case scanning
    case scanReview
    /// Fallback text-entry screen offered from the camera-permission-denied alert.
    /// Added in Task 4.1 alongside the view model — `OnboardingAnalyticsTracking`
    /// already anticipated it (`trackManualCardEntryScreenViewed`).
    case manualCardEntry
}

/// Which way the flow just moved — drives the slide transition's direction (push vs.
/// pop, mirroring `NavigationStack`) between `OnboardingFlowScreen`'s step content.
public enum OnboardingStepDirection: Sendable {
    case forward
    case backward
}

/// Result of reading a locally persisted checkpoint.
///
/// Unknown values stay unsupported so an older app cannot silently restart onboarding and
/// overwrite progress written by a newer version.
public enum PersistedOnboardingStep: Equatable, Sendable {
    case supported(OnboardingStep)
    case unsupported(rawValue: String)

    public init(rawValue: String) {
        if let step = OnboardingStep(rawValue: rawValue) {
            self = .supported(step)
        } else {
            self = .unsupported(rawValue: rawValue)
        }
    }

    public var rawValue: String {
        switch self {
        case .supported(let step):
            return step.rawValue
        case .unsupported(let rawValue):
            return rawValue
        }
    }

    public var supportedStep: OnboardingStep? {
        guard case .supported(let step) = self else { return nil }
        return step
    }
}

public enum OnboardingLanguageCode: String, Codable, Sendable, CaseIterable {
    case sk
    case hu
    case en
}

/// The two branches offered on the `loyaltyDecision` step. Not persisted until
/// `OnboardingViewModel.continueFromLoyaltyDecision()` — see the transition matrix's
/// "row choice itself is not stored until Continue" rule.
public enum OnboardingLoyaltyBranch: String, Equatable, Sendable, CaseIterable {
    case newCustomer
    case existingCard
}

/// Distinguishes the two claim-failure shapes the transition matrix calls out:
/// a card already owned by someone else gets its own alert copy/dismiss target,
/// everything else (not found, transient, already linked to this user via a race)
/// shares the generic "Something went wrong" retry/dismiss alert.
public enum OnboardingClaimFailureKind: Equatable, Sendable {
    case alreadyClaimedByOtherUser
    case generic
}

/// Where a claim attempt originated — drives analytics labels and the
/// already-claimed dismiss target (`scanning` vs `manualCardEntry`).
public enum OnboardingClaimSource: String, Equatable, Sendable {
    case scanner
    case manualEntry
}

/// System `.alert` presentations owned by the state machine. Screens (Task 4.2–4.5)
/// map each case to its localized title/message/actions — this type intentionally
/// carries no localized strings so the view model stays UI/locale-agnostic.
public enum OnboardingAlert: Equatable, Sendable, Identifiable {
    case createCardFailed
    case claimCardFailed(kind: OnboardingClaimFailureKind)
    case cameraPermissionDenied
    /// Bootstrap could not determine whether a loyalty card is already linked
    /// (network / rules / unexpected). Retry re-runs `bootstrap()`; do not continue
    /// into create/claim until this resolves — a false "no card" would risk racing
    /// an already-linked account.
    case bootstrapFetchFailed

    public var id: String {
        switch self {
        case .createCardFailed:
            return "createCardFailed"
        case .claimCardFailed(let kind):
            return "claimCardFailed.\(kind)"
        case .cameraPermissionDenied:
            return "cameraPermissionDenied"
        case .bootstrapFetchFailed:
            return "bootstrapFetchFailed"
        }
    }
}

public struct OnboardingProgress: Equatable, Sendable {
    public static let legacyVersion = 0
    public static let currentVersion = 1

    public let step: PersistedOnboardingStep
    public let language: OnboardingLanguageCode?
    public let version: Int

    public init(
        step: OnboardingStep,
        language: OnboardingLanguageCode? = nil,
        version: Int = OnboardingProgress.currentVersion
    ) {
        self.init(
            persistedStep: .supported(step),
            language: language,
            version: version
        )
    }

    public init(
        persistedStep: PersistedOnboardingStep,
        language: OnboardingLanguageCode? = nil,
        version: Int = OnboardingProgress.currentVersion
    ) {
        self.step = persistedStep
        self.language = language
        self.version = version
    }
}
