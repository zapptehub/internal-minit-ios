import Foundation

public enum OnboardingProgressStoreError: Error, Equatable {
    case corruptedData
}

/// Local, account-scoped persistence for resuming onboarding after app termination.
///
/// This boundary deliberately has no backend implementation: screen navigation is feature
/// state, not durable server data.
@MainActor
public protocol OnboardingProgressStoring: AnyObject {
    func load(userId: String) throws -> OnboardingProgress?
    func save(_ progress: OnboardingProgress, userId: String) throws
    func clear(userId: String)
}

@MainActor
public final class UserDefaultsOnboardingProgressStore: OnboardingProgressStoring {
    private let userDefaults: UserDefaults
    private let keyPrefix: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        userDefaults: UserDefaults = .standard,
        keyPrefix: String = "minit.onboarding.progress"
    ) {
        self.userDefaults = userDefaults
        self.keyPrefix = keyPrefix
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    public func load(userId: String) throws -> OnboardingProgress? {
        guard let data = userDefaults.data(forKey: key(userId: userId)) else {
            return nil
        }

        do {
            return try decoder.decode(StoredOnboardingProgress.self, from: data).toModel()
        } catch {
            throw OnboardingProgressStoreError.corruptedData
        }
    }

    public func save(_ progress: OnboardingProgress, userId: String) throws {
        let data = try encoder.encode(StoredOnboardingProgress(progress: progress))
        userDefaults.set(data, forKey: key(userId: userId))
    }

    public func clear(userId: String) {
        userDefaults.removeObject(forKey: key(userId: userId))
    }

    private func key(userId: String) -> String {
        "\(keyPrefix).\(userId)"
    }
}

private struct StoredOnboardingProgress: Codable {
    let step: String
    let language: String?
    let version: Int?

    init(progress: OnboardingProgress) {
        self.step = progress.step.rawValue
        self.language = progress.language?.rawValue
        self.version = progress.version
    }

    func toModel() -> OnboardingProgress {
        OnboardingProgress(
            persistedStep: PersistedOnboardingStep(rawValue: step),
            language: language.flatMap(OnboardingLanguageCode.init(rawValue:)),
            version: version ?? OnboardingProgress.legacyVersion
        )
    }
}
