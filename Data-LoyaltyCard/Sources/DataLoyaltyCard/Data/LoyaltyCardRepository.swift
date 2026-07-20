import Foundation

/// Public boundary for the rest of the app — no Firebase types appear here or in
/// any consumer.
public protocol LoyaltyCardRepository: Sendable {
    /// Idempotently create (or return the already-linked) card for `userId`.
    func createCard(userId: String) async throws -> LoyaltyCardData

    /// Idempotently claim an existing physical card by `code` for `userId`.
    /// Throws `LoyaltyCardError.alreadyClaimed` if linked to another user,
    /// `LoyaltyCardError.notFound` if the code is unknown,
    /// `LoyaltyCardError.alreadyLinked` if this user already has a different card.
    func claimCard(userId: String, code: String) async throws -> LoyaltyCardData

    /// Returns the card currently linked to `userId`, or `nil` if none.
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
        let dto = try await api.ensureCardOwned(
            code: linkedCode,
            ownerUserId: userId,
            points: Self.defaultNewCardPoints
        )
        return dto.toModel()
    }

    public func claimCard(userId: String, code: String) async throws -> LoyaltyCardData {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw LoyaltyCardError.notFound
        }

        if let linkedId = try await api.fetchLinkedCardId(userId: userId) {
            if linkedId == normalized {
                if let card = try await api.fetchCard(code: linkedId) {
                    return card.toModel()
                }
                // Link pointer exists but card record is missing — fall through and
                // re-claim / re-ensure via the claim path below.
            } else {
                throw LoyaltyCardError.alreadyLinked
            }
        }

        let claimed = try await api.claimExistingCard(code: normalized, userId: userId)
        let linkedCode = try await api.linkCardIdIfAbsent(userId: userId, code: normalized)
        guard linkedCode == normalized else {
            // Another concurrent create won the user link.
            throw LoyaltyCardError.alreadyLinked
        }
        return claimed.toModel()
    }

    public func fetchLinkedCard(userId: String) async throws -> LoyaltyCardData? {
        guard let linkedId = try await api.fetchLinkedCardId(userId: userId) else {
            return nil
        }
        guard let dto = try await api.fetchCard(code: linkedId) else {
            return nil
        }
        return dto.toModel()
    }

    static func makeNewCardCode() -> String {
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return "MINIT-\(token.prefix(10).uppercased())"
    }
}
