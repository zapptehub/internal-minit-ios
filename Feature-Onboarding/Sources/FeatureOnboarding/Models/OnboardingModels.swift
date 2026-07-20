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
