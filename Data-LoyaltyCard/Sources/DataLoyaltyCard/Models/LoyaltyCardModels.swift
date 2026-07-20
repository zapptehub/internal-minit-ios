/// Domain model for a loyalty card. No Firebase types appear here.
public struct LoyaltyCardData: Equatable, Sendable {
    public let code: String
    public let ownerUserId: String?
    /// Points balance on the card. Freshly created cards start at `0`.
    public let points: Int?

    public init(code: String, ownerUserId: String? = nil, points: Int? = nil) {
        self.code = code
        self.ownerUserId = ownerUserId
        self.points = points
    }
}

/// Wire DTO for `loyaltyCards/{code}` nodes. Firebase Codable mapping stays inside
/// `Data-LoyaltyCard`; feature code only sees `LoyaltyCardData`.
public struct LoyaltyCardDto: Codable, Equatable, Sendable {
    public let code: String
    public let ownerUserId: String?
    public let points: Int?

    public init(code: String, ownerUserId: String? = nil, points: Int? = nil) {
        self.code = code
        self.ownerUserId = ownerUserId
        self.points = points
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case ownerUserId
        case points
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        ownerUserId = try container.decodeIfPresent(String.self, forKey: .ownerUserId)
        points = try container.decodeIfPresent(Int.self, forKey: .points)
    }
}

public extension LoyaltyCardDto {
    func toModel() -> LoyaltyCardData {
        LoyaltyCardData(code: code, ownerUserId: ownerUserId, points: points)
    }
}

public extension LoyaltyCardData {
    func toDto() -> LoyaltyCardDto {
        LoyaltyCardDto(code: code, ownerUserId: ownerUserId, points: points)
    }
}

/// Typed failures the feature layer can switch on without importing Firebase.
public enum LoyaltyCardError: Error, Equatable, Sendable {
    /// The card code does not exist in the registry.
    case notFound
    /// The card is already linked to a different user account.
    case alreadyClaimed
    /// The current user already has a different linked card.
    case alreadyLinked
    /// Catch-all for transport / rules / unexpected backend failures.
    case underlying(String)
}
