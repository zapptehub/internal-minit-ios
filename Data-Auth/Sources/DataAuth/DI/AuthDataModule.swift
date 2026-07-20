import CoreNetworking

public final class AuthDataModule {
    private let networkClient: NetworkClient

    public init(networkClient: NetworkClient) {
        self.networkClient = networkClient
    }

    private lazy var api: AuthApi = FirebaseAuthApiImpl()
    private lazy var dataSource: AuthDataSource = InMemoryAuthDataSource()
    private lazy var repository: AuthRepository = AuthRepositoryImpl(api: api, dataSource: dataSource)

    public func makeAuthRepository() -> AuthRepository { repository }
}
