import Foundation
import CoreLogging
import CoreExtensions
import CoreNetworking
import DataAuth
import DataProfile
import DataLoyaltyCard
import DesignSystem
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
    /// Gates Start's "Try Minit in Demo mode" button. This is `MinitDemoEnabled`
    /// (`YES` on Debug and Internal, `NO` on Release). A bad backend id fails
    /// before this is set.
    let showsDemo: Bool

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
        self.showsDemo = Self.demoEnabled()
        #if MINIT_SHAKE
        let reportAddress = Self.reportAddress()
        self.reportAddress = reportAddress
        ShakeReportLog.shared.setEnabled(reportAddress != nil)
        if reportAddress != nil {
            ShakeReportHooks.install()
            AppLogger.lineSink = { ShakeReportLog.shared.record($0) }
            DiagnosticLines.record = { ShakeReportLog.shared.record($0) }
        }
        #endif
    }

    #if MINIT_SHAKE
    /// `MinitShakeReportEmail` when it expanded to a non-empty address. Empty, missing,
    /// or a leftover `$(` token leaves shake-to-report off.
    let reportAddress: String?

    static func reportAddress(bundle: Bundle = .main) -> String? {
        ShakeReportGate.address(from: plistString("MinitShakeReportEmail", bundle: bundle))
    }
    #endif

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
    /// Debug, Internal, and Release commit `http`. Gitignored `Config/Local.xcconfig`
    /// may override Debug or Internal. `http` is the only id. A missing, unexpanded,
    /// `firebase`, or any other value fails here, before a repository is built.
    private static func dataBackend(bundle: Bundle = .main) -> String {
        switch resolveDataBackendID(plistString("MinitDataBackend", bundle: bundle)) {
        case .success(let id):
            return id
        case .failure(let error):
            fatalError(error.description)
        }
    }

    /// `MinitDemoEnabled` from Info.plist (`MINIT_DEMO_ENABLED`, `YES` in Debug/Internal,
    /// `NO` in Release). A missing, unexpanded, or non-`YES` value is treated as off, so a
    /// host plist that never sets the key stays hidden.
    private static func demoEnabled(bundle: Bundle = .main) -> Bool {
        plistString("MinitDemoEnabled", bundle: bundle).trimmingCharacters(in: .whitespacesAndNewlines) == "YES"
    }

    private static func plistString(_ key: String, bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}
