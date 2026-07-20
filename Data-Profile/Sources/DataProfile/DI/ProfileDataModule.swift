public final class ProfileDataModule {
    public init() {}

    private lazy var api: ProfileApi = FirebaseProfileApiImpl()
    private lazy var repository: ProfileRepository = ProfileRepositoryImpl(api: api)

    public func makeProfileRepository() -> ProfileRepository { repository }
}
