import CoreNetworking

/// Composition root for loyalty-card data.
///
/// `dataBackend` selects the repository. The HTTP type is constructed only
/// when the id is `http`. Firebase Realtime Database reads and writes stay
/// on `LoyaltyCardRepositoryImpl`.
public final class LoyaltyCardDataModule {
    private let dataBackend: String
    private let networkClient: (any NetworkClient)?

    /// `dataBackend` is the plist id (`firebase` or `http`). A nil client is
    /// ignored unless the id is `http`.
    public init(dataBackend: String = "firebase", networkClient: (any NetworkClient)? = nil) {
        let id = dataBackend.trimmingCharacters(in: .whitespacesAndNewlines)
        self.dataBackend = id
        self.networkClient = id == Self.httpBackend ? networkClient : nil
    }

    public func makeLoyaltyCardRepository() -> LoyaltyCardRepository { repository }

    private lazy var repository: LoyaltyCardRepository = makeRepository()

    private func makeRepository() -> LoyaltyCardRepository {
        switch dataBackend {
        case Self.httpBackend:
            guard let networkClient else {
                fatalError("MinitDataBackend is http but no NetworkClient was provided")
            }
            return HttpLoyaltyCardRepository(client: networkClient)
        case Self.firebaseBackend:
            return LoyaltyCardRepositoryImpl(api: FirebaseLoyaltyCardApiImpl())
        default:
            fatalError("Unknown data backend \"\(dataBackend)\"")
        }
    }

    private static let firebaseBackend = "firebase"
    private static let httpBackend = "http"
}
