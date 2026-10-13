/// Low-level loyalty-card backend boundary. Orchestration / idempotency lives in
/// `LoyaltyCardRepositoryImpl`. Create uses a single-node link transaction.
/// Claim uses one multi-path update so ownership and the user link commit
/// together. No Firebase types escape here.
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

    /// Claims `loyaltyCards/{code}` for `userId` and sets
    /// `users/{userId}/loyaltyCardId` to `code` in one update.
    ///
    /// Realtime Database transactions cover a single node, and the security
    /// rules reject both changing `loyaltyCardId` and clearing `ownerUserId`.
    /// Separate writes can leave a card owned after the link is lost, and that
    /// ownership cannot be rolled back. Linking first would permanently attach
    /// the loser of a two-user claim to a card they do not own. This update
    /// commits both locations or neither.
    ///
    /// A missing card fails as `.notFound`. Another owner's card fails as
    /// `.alreadyClaimed`. An existing link to a different code fails as
    /// `.alreadyLinked`. Owning the card already is idempotent and still writes
    /// a missing link.
    func claimAndLink(code: String, userId: String) async throws -> LoyaltyCardDto
}
