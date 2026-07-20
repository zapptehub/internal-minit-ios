/// Low-level loyalty-card backend boundary. Orchestration / idempotency lives in
/// `LoyaltyCardRepositoryImpl`; this protocol exposes the primitive reads and
/// single-node transactions the Firebase impl needs. No Firebase types escape here.
public protocol LoyaltyCardApi: Sendable {
    /// Returns `users/{uid}/loyaltyCardId`, or `nil` when unset.
    func fetchLinkedCardId(userId: String) async throws -> String?

    /// Atomically writes `loyaltyCardId` only when absent. Returns the code linked
    /// after the transaction (the existing value if another writer won the race).
    func linkCardIdIfAbsent(userId: String, code: String) async throws -> String

    /// One-shot read of `loyaltyCards/{code}`.
    func fetchCard(code: String) async throws -> LoyaltyCardDto?

    /// Ensures `loyaltyCards/{code}` exists and is owned by `ownerUserId`.
    /// Creates the record when missing; no-ops when already owned by the same user.
    /// Throws `LoyaltyCardError.alreadyClaimed` if owned by someone else.
    func ensureCardOwned(code: String, ownerUserId: String, points: Int) async throws -> LoyaltyCardDto

    /// Claims an existing registry card for `userId`. Throws `.notFound` when the
    /// code is unknown, `.alreadyClaimed` when owned by another user. Idempotent
    /// when the card is already owned by `userId`.
    func claimExistingCard(code: String, userId: String) async throws -> LoyaltyCardDto
}
