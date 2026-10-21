import Foundation
import CoreLogging
import CoreExtensions
import CoreNetworking
import DataAuth
import DataProfile
import DataLoyaltyCard
import FeatureLogin
import FeatureStart
import FeatureOnboarding

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()

    let networkClient: NetworkClientImpl
    /// Live path reachability for Features to inject later (no UI wiring yet).
    let reachability: any Reachability
    let authDataModule: AuthDataModule
    let authRepository: AuthRepository
    let profileDataModule: ProfileDataModule
    let profileRepository: ProfileRepository
    let loyaltyCardDataModule: LoyaltyCardDataModule
    let loyaltyCardRepository: LoyaltyCardRepository
    /// Local, account-scoped resume checkpoint for `FeatureOnboarding` — not durable
    /// backend data, so it lives here as a plain `UserDefaults`-backed store rather
    /// than behind a Data-* package.
    let onboardingProgressStore: any OnboardingProgressStoring
    /// Device-wide (not account-scoped) language preference — survives logout/
    /// re-login, unlike `onboardingProgressStore`. See `AppLanguagePreferenceStoring`.
    let appLanguagePreference: any AppLanguagePreferenceStoring
    let errorReporter: ErrorReporter
    let loginAnalytics: LoginAnalyticsTracking
    let startAnalytics: StartAnalyticsTracking
    let onboardingAnalytics: OnboardingAnalyticsTracking

    private init() {
        let networkClient = NetworkClientImpl(baseURL: Self.apiBaseURL())
        self.networkClient = networkClient
        self.reachability = PathReachability()

        let authDataModule = AuthDataModule(networkClient: networkClient)
        self.authDataModule = authDataModule
        self.authRepository = authDataModule.makeAuthRepository()

        let profileDataModule = ProfileDataModule()
        self.profileDataModule = profileDataModule
        self.profileRepository = profileDataModule.makeProfileRepository()

        let loyaltyCardDataModule = LoyaltyCardDataModule()
        self.loyaltyCardDataModule = loyaltyCardDataModule
        self.loyaltyCardRepository = loyaltyCardDataModule.makeLoyaltyCardRepository()

        self.onboardingProgressStore = UserDefaultsOnboardingProgressStore()
        self.appLanguagePreference = UserDefaultsAppLanguagePreferenceStore()

        self.errorReporter = ConsoleErrorReporter()
        self.loginAnalytics = ConsoleAnalyticsAdapter()
        self.startAnalytics = ConsoleStartAnalyticsAdapter()
        self.onboardingAnalytics = ConsoleOnboardingAnalyticsAdapter()
    }

    /// `MinitAPIBaseURL` from Info.plist (`MINIT_API_BASE_URL` in the configuration xcconfig).
    /// Requires an absolute `http` or `https` URL with a host, no query or fragment, and no trailing slash.
    /// xcconfig treats `//` as a comment, so overrides are written `https:/$()/`.
    private static func apiBaseURL(bundle: Bundle = .main) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: "MinitAPIBaseURL") as? String else {
            fatalError("MinitAPIBaseURL is missing from Info.plist")
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            fatalError("MinitAPIBaseURL is empty or unexpanded in Info.plist (value: \"\(trimmed)\")")
        }
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty,
              components.query == nil,
              components.fragment == nil,
              !trimmed.hasSuffix("/") else {
            fatalError(
                "MinitAPIBaseURL must be an http or https URL with a host, no query or fragment, and no trailing slash (value: \"\(trimmed)\")"
            )
        }
        return trimmed
    }
}
