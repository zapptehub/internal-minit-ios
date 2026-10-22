import Foundation
import CoreLogging
import CoreExtensions
import CoreNetworking
import DataAuth
import DataProfile
import DataLoyaltyCard
import FeatureHome
import FeatureLogin
import FeatureStart
import FeatureOnboarding

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()

    let apiBaseURL: String
    let networkClient: NetworkClientImpl
    let homeRepository: any HomeRepository
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
        let authDataModule = AuthDataModule()
        self.authDataModule = authDataModule
        self.authRepository = authDataModule.makeAuthRepository()

        let apiBaseURL = Self.apiBaseURL()
        self.apiBaseURL = apiBaseURL
        let networkClient = NetworkClientImpl(
            baseURL: apiBaseURL,
            tokenProvider: authDataModule.tokenProvider,
            accessClientId: Self.plistString("CFAccessClientId"),
            accessClientSecret: Self.plistString("CFAccessClientSecret")
        )
        self.networkClient = networkClient
        let dataBackend = Self.dataBackend()
        self.homeRepository = HomeRepositoryFactory.make(
            dataBackend: dataBackend,
            networkClient: networkClient
        )
        self.reachability = PathReachability()

        let profileDataModule = ProfileDataModule(
            dataBackend: dataBackend,
            networkClient: networkClient
        )
        self.profileDataModule = profileDataModule
        self.profileRepository = profileDataModule.makeProfileRepository()

        let loyaltyCardDataModule = LoyaltyCardDataModule(
            dataBackend: dataBackend,
            networkClient: networkClient
        )
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

    /// `MinitDataBackend` from Info.plist (`MINIT_DATA_BACKEND`).
    ///
    /// Debug and Internal commit `http`. Release commits `firebase`. Gitignored
    /// `Config/Local.xcconfig` may override Debug or Internal. The data modules
    /// construct the HTTP repositories only when the id is `http`.
    ///
    /// A missing or unexpanded value defaults to `firebase`, so a host plist
    /// that never sets the key stays on Firebase.
    /// Any other id still fails when the data module builds the repository.
    private static func dataBackend(bundle: Bundle = .main) -> String {
        let value = plistString("MinitDataBackend", bundle: bundle)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value.hasPrefix("$(") {
            return "firebase"
        }
        return value
    }

    private static func plistString(_ key: String, bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
