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
    /// Transport, rules, decoding, or an unexpected backend failure.
    ///
    /// The associated value keeps the typed source and drops
    /// `localizedDescription`. That string follows the device language and can
    /// include database paths, user ids, card codes, and server bodies.
    case underlying(Underlying)

    /// Typed source for ``underlying(_:)``.
    ///
    /// Firebase Realtime Database exposes only a few stable `NSError` codes.
    /// `com.firebase` / `1` is `permission_denied` and `com.firebase` / `2` is
    /// `unavailable` (`FUtilities.errorCodes`). Disconnect, offline, generic
    /// `failed`, and `maxretry` share code `9999`. A failed `getData()` with an
    /// empty cache is `com.firebase.core` / `1` for every status, including
    /// permission denied. There is no timeout code on this path.
    public enum Underlying: Equatable, Sendable {
        /// `NSError` domain used by Firebase Realtime Database (`kFErrorDomain`).
        public static let firebaseDatabaseDomain = "com.firebase"
        /// `permission_denied`.
        public static let firebasePermissionDeniedCode = 1
        /// `unavailable`.
        public static let firebaseUnavailableCode = 2

        /// The stored record could not be decoded or was not the expected shape.
        case decoding
        /// Firebase `NSError` reduced to domain and code. The localized message is omitted.
        case database(domain: String, code: Int)
        /// No SDK error to classify, such as a transaction that did not commit.
        case unknown
    }
}
