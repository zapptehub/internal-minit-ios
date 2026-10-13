import Foundation

/// Public boundary for the rest of the app — no Firebase types appear here or in
/// any consumer.
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
}

public final class LoyaltyCardRepositoryImpl: LoyaltyCardRepository {
    public static let defaultNewCardPoints = 0

    private let api: LoyaltyCardApi

    public init(api: LoyaltyCardApi) {
        self.api = api
    }

    public func createCard(userId: String) async throws -> LoyaltyCardData {
        if let existing = try await fetchLinkedCard(userId: userId) {
            return existing
        }

        let candidateCode = Self.makeNewCardCode()
        let linkedCode = try await api.linkCardIdIfAbsent(userId: userId, code: candidateCode)
        // Android throws InvalidData (analytics "decoding") for a stored id that
        // cannot be a card key. iOS has no InvalidData case.
        guard linkedCode.isValidLoyaltyCardCode() else {
            throw LoyaltyCardError.underlying(.decoding)
        }
        let dto = try await api.ensureCardOwned(
            code: linkedCode,
            ownerUserId: userId,
            points: Self.defaultNewCardPoints
        )
        return dto.toModel()
    }

    public func claimCard(userId: String, code: String) async throws -> LoyaltyCardData {
        let normalized = code.normalizeLoyaltyCardCode()
        guard normalized.isValidLoyaltyCardCode() else {
            throw LoyaltyCardError.notFound
        }

        if let linkedId = try await api.fetchLinkedCardId(userId: userId) {
            if linkedId == normalized {
                if let card = try await api.fetchCard(code: linkedId),
                   card.ownerUserId == userId {
                    return card.toModel()
                }
                // The pointer may outlive a deleted or unowned record. A foreign
                // owner falls through to claimAndLink, which reports alreadyClaimed.
            } else {
                throw LoyaltyCardError.alreadyLinked
            }
        }

        // Ownership and the user link commit together. Rules make both permanent,
        // so a lost link must not leave this card owned.
        let claimed = try await api.claimAndLink(code: normalized, userId: userId)
        return claimed.toModel()
    }

    public func fetchLinkedCard(userId: String) async throws -> LoyaltyCardData? {
        guard let linkedId = try await api.fetchLinkedCardId(userId: userId) else {
            return nil
        }
        guard linkedId.isValidLoyaltyCardCode() else {
            return nil
        }
        guard let dto = try await api.fetchCard(code: linkedId) else {
            return nil
        }
        guard dto.ownerUserId == userId else {
            return nil
        }
        return dto.toModel()
    }

    static func makeNewCardCode() -> String {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "MINIT-\(token.prefix(10).uppercased())"
    }
}
