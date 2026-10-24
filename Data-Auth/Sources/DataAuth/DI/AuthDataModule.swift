import CoreNetworking

public final class AuthDataModule {
    private let api: AuthApi
    private let dataSource: AuthDataSource
    private let repository: AuthRepository
    /// `DemoAwareTokenProvider` wrapping the Firebase implementation — reads
    /// `demoSessionStore` before Firebase. `PlaceholderAuthProvider` waits until phase 6.
    public let tokenProvider: TokenProvider
    /// In-memory-only demo session token (see `DemoSessionTokenStore`). The App target
    /// sets this after `POST /v1/demo/session` and clears it on logout and when starting
    /// an email login.
    public let demoSessionStore = DemoSessionTokenStore()

    public init() {
        let firebase = FirebaseAuthApiImpl()
        self.api = firebase
        self.tokenProvider = DemoAwareTokenProvider(
            demoSessionStore: demoSessionStore,
            firebaseTokenProvider: firebase
        )
        let dataSource = InMemoryAuthDataSource()
        self.dataSource = dataSource
        self.repository = AuthRepositoryImpl(api: firebase, dataSource: dataSource)
    }

    public func makeAuthRepository() -> AuthRepository { repository }
}
