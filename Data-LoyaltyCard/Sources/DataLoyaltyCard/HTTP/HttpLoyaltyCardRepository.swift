import CoreNetworking
import Foundation

/// HTTP `LoyaltyCardRepository`.
///
/// Create is one `POST /v1/me/loyalty-card` with no body. The server mints the
/// code; this type does not. Claim trims and validates locally, then one
/// `POST /v1/loyalty-cards/{code}/claim`. It does not read the lookup route.
/// Paths use the token subject. `userId` is not sent; it is stored as
/// `ownerUserId` because the card JSON has no owner.
///
/// Points history is `GET /v1/me/points-history`. `cursor` is one query value.
/// A 404 `not_found` is an empty page. `limit` is sent coerced to 1...50,
/// which is the range the route accepts.
final class HttpLoyaltyCardRepository: LoyaltyCardRepository {
    private let client: any NetworkClient

    init(client: any NetworkClient) {
        self.client = client
    }

    func createCard(userId: String) async throws -> LoyaltyCardData {
        try await mapLoyalty {
            let response: LoyaltyCardResponse = try await client.request(Self.myCard, method: .POST)
            return response.toModel(ownerUserId: userId)
        }
    }

    func claimCard(userId: String, code: String) async throws -> LoyaltyCardData {
        let normalized = code.normalizeLoyaltyCardCode()
        guard normalized.isValidLoyaltyCardCode() else {
            throw LoyaltyCardError.notFound
        }
        let path = "/v1/loyalty-cards/\(LoyaltyURLEncoding.component(normalized))/claim"
        return try await mapLoyalty {
            let response: LoyaltyCardResponse = try await client.request(path, method: .POST)
            return response.toModel(ownerUserId: userId)
        }
    }

    func fetchLinkedCard(userId: String) async throws -> LoyaltyCardData? {
        let response = try await valueOrNilOnNotFound { () async throws -> LoyaltyCardResponse in
            try await client.request(Self.myCard, method: .GET)
        }
        return response?.toModel(ownerUserId: userId)
    }

    func fetchPointsHistory(limit: Int, cursor: String?) async throws -> PointsHistoryPage {
        let path = Self.pointsHistoryPath(limit: limit, cursor: cursor)
        let response = try await valueOrNilOnNotFound { () async throws -> PointsHistoryResponse in
            try await client.request(path, method: .GET)
        }
        return response?.toModel() ?? PointsHistoryPage(items: [], nextCursor: nil)
    }

    private func mapLoyalty<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch {
            switch classifyLoyaltyCatch(error) {
            case .cancelled(let cancellation):
                throw cancellation
            case .notFound:
                throw LoyaltyCardError.notFound
            case .failure(let failure):
                throw failure
            }
        }
    }

    /// `404` `not_found` is nil. Every other failure is a `LoyaltyCardError`.
    private func valueOrNilOnNotFound<T>(_ operation: () async throws -> T) async throws -> T? {
        do {
            return try await operation()
        } catch {
            switch classifyLoyaltyCatch(error) {
            case .cancelled(let cancellation):
                throw cancellation
            case .notFound:
                return nil
            case .failure(let failure):
                throw failure
            }
        }
    }

    private static let myCard = "/v1/me/loyalty-card"
    private static let historyLimitMinimum = 1
    private static let historyLimitMaximum = 50

    private static func pointsHistoryPath(limit: Int, cursor: String?) -> String {
        let bounded = min(max(limit, historyLimitMinimum), historyLimitMaximum)
        var path = "/v1/me/points-history?limit=\(bounded)"
        if let cursor {
            path.append("&cursor=")
            path.append(LoyaltyURLEncoding.component(cursor))
        }
        return path
    }
}

private enum LoyaltyCatch {
    case cancelled(Error)
    case notFound
    case failure(LoyaltyCardError)
}

private func classifyLoyaltyCatch(_ error: Error) -> LoyaltyCatch {
    if error is CancellationError {
        return .cancelled(error)
    }
    if let urlError = error as? URLError, urlError.code == .cancelled {
        return .cancelled(urlError)
    }
    if let loyalty = error as? LoyaltyCardError {
        return .failure(loyalty)
    }
    if let network = error as? NetworkError {
        if network.isLoyaltyNotFound() {
            return .notFound
        }
        return .failure(network.toLoyaltyCardError())
    }
    return .failure(.underlying(.unknown))
}

/// One path or query component. UTF-8 percent-encoding, space as `%20`.
enum LoyaltyURLEncoding {
    static func component(_ value: String) -> String {
        let hex = Array("0123456789ABCDEF")
        var encoded = ""
        encoded.reserveCapacity(value.utf8.count)
        for byte in value.utf8 {
            switch byte {
            case UInt8(ascii: "A")...UInt8(ascii: "Z"),
                 UInt8(ascii: "a")...UInt8(ascii: "z"),
                 UInt8(ascii: "0")...UInt8(ascii: "9"),
                 UInt8(ascii: "-"),
                 UInt8(ascii: "."),
                 UInt8(ascii: "_"),
                 UInt8(ascii: "~"):
                encoded.append(Character(UnicodeScalar(byte)))
            default:
                encoded.append("%")
                encoded.append(hex[Int(byte >> 4)])
                encoded.append(hex[Int(byte & 0x0F)])
            }
        }
        return encoded
    }
}
