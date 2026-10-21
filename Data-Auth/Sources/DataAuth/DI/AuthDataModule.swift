import CoreNetworking

public final class AuthDataModule {
    private let api: AuthApi
    private let dataSource: AuthDataSource
    private let repository: AuthRepository
    /// The Firebase implementation. `PlaceholderAuthProvider` waits until phase 6.
    public let tokenProvider: TokenProvider

    public init() {
        let firebase = FirebaseAuthApiImpl()
        self.api = firebase
        self.tokenProvider = firebase
        let dataSource = InMemoryAuthDataSource()
        self.dataSource = dataSource
        self.repository = AuthRepositoryImpl(api: firebase, dataSource: dataSource)
    }

    public func makeAuthRepository() -> AuthRepository { repository }
}
