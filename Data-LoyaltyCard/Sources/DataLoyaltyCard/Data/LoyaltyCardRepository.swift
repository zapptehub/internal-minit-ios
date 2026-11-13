/// Public boundary for the rest of the app.
public protocol LoyaltyCardRepository: Sendable {
    /// Idempotently create (or return the already-linked) card for `userId`.
    /// A stored link that cannot be a database key throws
    /// `LoyaltyCardError.underlying(.decoding)`.
    func createCard(userId: String) async throws -> LoyaltyCardData

    /// Idempotently claim an existing physical card by `code` for `userId`.
    /// Throws `LoyaltyCardError.alreadyClaimed` if linked to another user,
    /// `LoyaltyCardError.notFound` if the code is blank, not a Firebase key, or unknown,
    /// `LoyaltyCardError.alreadyLinked` if this user already has a different card.
    func claimCard(userId: String, code: String) async throws -> LoyaltyCardData

    /// Returns the card linked to `userId` when that user owns it, or `nil`
    /// when none is linked, the stored id cannot be a database key, or
    /// another user owns the record.
    func fetchLinkedCard(userId: String) async throws -> LoyaltyCardData?

    /// One page of the caller's points ledger.
    ///
    /// A conformer that does not override this gets an empty page (`nextCursor` nil).
    /// `HttpLoyaltyCardRepository` reads `GET /v1/me/points-history`. A 404
    /// `not_found` is that empty page. `cursor` is one encoded query value.
    /// The HTTP implementation clamps `limit` to 1...50 before the request,
    /// which is the range the route accepts. A caller that asks for 100 is
    /// sent 50 and may still receive a `nextCursor`, with no separate signal
    /// that the page is shorter than requested. No screen reads this.
    func fetchPointsHistory(limit: Int, cursor: String?) async throws -> PointsHistoryPage
}

extension LoyaltyCardRepository {
    public func fetchPointsHistory(limit _: Int, cursor _: String?) async throws -> PointsHistoryPage {
        PointsHistoryPage(items: [], nextCursor: nil)
    }
}
