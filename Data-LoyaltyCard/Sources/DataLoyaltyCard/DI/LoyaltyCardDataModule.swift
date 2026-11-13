import CoreNetworking

/// Composition root for loyalty-card data.
///
/// Builds `HttpLoyaltyCardRepository`. `dataBackend` must be `http`; the app
/// rejects every other id before it constructs this module. Surrounding
/// whitespace is ignored.
public final class LoyaltyCardDataModule {
    private let repository: HttpLoyaltyCardRepository

    public init(dataBackend: String, networkClient: any NetworkClient) {
        let id = dataBackend.trimmingCharacters(in: .whitespacesAndNewlines)
        precondition(id == "http", "LoyaltyCardDataModule only builds the http repository")
        self.repository = HttpLoyaltyCardRepository(client: networkClient)
    }

    public func makeLoyaltyCardRepository() -> LoyaltyCardRepository { repository }
}
