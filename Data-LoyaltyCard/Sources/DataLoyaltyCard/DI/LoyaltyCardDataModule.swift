/// Composition root for loyalty-card data. Wires the Firebase API into the
/// public `LoyaltyCardRepository` boundary.
public final class LoyaltyCardDataModule {
    public init() {}

    private lazy var api: LoyaltyCardApi = FirebaseLoyaltyCardApiImpl()
    private lazy var repository: LoyaltyCardRepository = LoyaltyCardRepositoryImpl(api: api)

    public func makeLoyaltyCardRepository() -> LoyaltyCardRepository { repository }
}
