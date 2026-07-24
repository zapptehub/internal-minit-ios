import CoreLogging
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
    let errorReporter: ErrorReporter
    let loginAnalytics: LoginAnalyticsTracking
    let startAnalytics: StartAnalyticsTracking
    let onboardingAnalytics: OnboardingAnalyticsTracking

    private init() {
        let networkClient = NetworkClientImpl(baseURL: "https://api.minit.app")
        self.networkClient = networkClient

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

        self.errorReporter = ConsoleErrorReporter()
        self.loginAnalytics = ConsoleAnalyticsAdapter()
        self.startAnalytics = ConsoleStartAnalyticsAdapter()
        self.onboardingAnalytics = ConsoleOnboardingAnalyticsAdapter()
    }
}
