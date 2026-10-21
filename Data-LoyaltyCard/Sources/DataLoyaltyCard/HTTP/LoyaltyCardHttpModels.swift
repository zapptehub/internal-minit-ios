import Foundation

/// `GET` and `POST` loyalty-card body.
///
/// The wire object has no owner. The repository sets `ownerUserId` from the
/// `userId` argument. `tierId` is decoded and not stored on `LoyaltyCardData`.
struct LoyaltyCardResponse: Decodable, Equatable, Sendable {
    let code: String
    let points: Int
    let tierId: String

    func toModel(ownerUserId: String) -> LoyaltyCardData {
        LoyaltyCardData(code: code, ownerUserId: ownerUserId, points: points)
    }
}

/// Lookup body. Exactly `code` and `status`.
///
/// `registered` is not a `LoyaltyCardData`. Claim does not call this route.
struct LoyaltyCardLookupResponse: Decodable, Equatable, Sendable {
    let code: String
    let status: String
}

struct PointsHistoryResponse: Decodable, Equatable, Sendable {
    let items: [PointsHistoryItemResponse]
    let nextCursor: String?

    func toModel() -> PointsHistoryPage {
        PointsHistoryPage(
            items: items.map { $0.toModel() },
            nextCursor: nextCursor
        )
    }
}

struct PointsHistoryItemResponse: Decodable, Equatable, Sendable {
    let id: String
    let delta: Int
    let balanceAfter: Int
    let reasonKey: String
    let reason: PointsReasonResponse
    let createdAt: String

    func toModel() -> PointsTransaction {
        PointsTransaction(
            id: id,
            delta: delta,
            balanceAfter: balanceAfter,
            reasonKey: reasonKey,
            reason: PointsTransactionReason(en: reason.en, sk: reason.sk, hu: reason.hu),
            createdAt: createdAt
        )
    }
}

struct PointsReasonResponse: Decodable, Equatable, Sendable {
    let en: String
    let sk: String
    let hu: String
}
