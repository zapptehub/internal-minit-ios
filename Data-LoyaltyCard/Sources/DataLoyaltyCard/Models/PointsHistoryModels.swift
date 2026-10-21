/// One page of the caller's points ledger.
///
/// `nextCursor` is nil on the last page. No screen reads this.
public struct PointsHistoryPage: Equatable, Sendable {
    public let items: [PointsTransaction]
    public let nextCursor: String?

    public init(items: [PointsTransaction], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// One ledger row.
///
/// `reason` is the server label for `en`, `sk`, and `hu`. `createdAt` is the
/// API timestamp text, not a parsed `Date`.
public struct PointsTransaction: Equatable, Sendable {
    public let id: String
    public let delta: Int
    public let balanceAfter: Int
    public let reasonKey: String
    public let reason: PointsTransactionReason
    public let createdAt: String

    public init(
        id: String,
        delta: Int,
        balanceAfter: Int,
        reasonKey: String,
        reason: PointsTransactionReason,
        createdAt: String
    ) {
        self.id = id
        self.delta = delta
        self.balanceAfter = balanceAfter
        self.reasonKey = reasonKey
        self.reason = reason
        self.createdAt = createdAt
    }
}

/// Localized ledger label. The keys are the API language codes.
public struct PointsTransactionReason: Equatable, Sendable {
    public let en: String
    public let sk: String
    public let hu: String

    public init(en: String, sk: String, hu: String) {
        self.en = en
        self.sk = sk
        self.hu = hu
    }
}
