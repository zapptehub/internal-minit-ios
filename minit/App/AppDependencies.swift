import CoreLogging
import DataAuth
import DataProfile
import FeatureLogin
import FeatureStart

@MainActor
final class AppDependencies {
    static let shared = AppDependencies()

    let networkClient: NetworkClientImpl
    let authDataModule: AuthDataModule
    let authRepository: AuthRepository
    let profileDataModule: ProfileDataModule
    let profileRepository: ProfileRepository
    let errorReporter: ErrorReporter
    let loginAnalytics: LoginAnalyticsTracking
    let startAnalytics: StartAnalyticsTracking

    private init() {
        let networkClient = NetworkClientImpl(baseURL: "https://api.minit.app")
        self.networkClient = networkClient

        let authDataModule = AuthDataModule(networkClient: networkClient)
        self.authDataModule = authDataModule
        self.authRepository = authDataModule.makeAuthRepository()

        let profileDataModule = ProfileDataModule()
        self.profileDataModule = profileDataModule
        self.profileRepository = profileDataModule.makeProfileRepository()

        self.errorReporter = ConsoleErrorReporter()
        self.loginAnalytics = ConsoleAnalyticsAdapter()
        self.startAnalytics = ConsoleStartAnalyticsAdapter()
    }
}
