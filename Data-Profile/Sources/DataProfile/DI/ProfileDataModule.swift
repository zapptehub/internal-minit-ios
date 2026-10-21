import CoreNetworking

/// Composition root for profile data.
///
/// `dataBackend` selects the repository. The HTTP type is constructed only
/// when the id is `http`. Firebase Realtime Database reads and writes stay
/// on `ProfileRepositoryImpl`.
public final class ProfileDataModule {
    private let dataBackend: String
    private let networkClient: (any NetworkClient)?

    /// `dataBackend` is the plist id (`firebase` or `http`). A nil client is
    /// ignored unless the id is `http`.
    public init(dataBackend: String = "firebase", networkClient: (any NetworkClient)? = nil) {
        let id = dataBackend.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dataBackend = id
        self.networkClient = id == Self.httpBackend ? networkClient : nil
    }

    public func makeProfileRepository() -> ProfileRepository { repository }

    private lazy var repository: ProfileRepository = makeRepository()

    private func makeRepository() -> ProfileRepository {
        switch dataBackend {
        case Self.httpBackend:
            guard let networkClient else {
                fatalError("MinitDataBackend is http but no NetworkClient was provided")
            }
            return HttpProfileRepository(client: networkClient)
        case Self.firebaseBackend:
            return ProfileRepositoryImpl(api: FirebaseProfileApiImpl())
        default:
            fatalError("Unknown data backend \"\(dataBackend)\"")
        }
    }

    private static let firebaseBackend = "firebase"
    private static let httpBackend = "http"
}
