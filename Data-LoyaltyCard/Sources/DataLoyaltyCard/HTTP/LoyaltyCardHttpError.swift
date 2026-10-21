import CoreNetworking
import Foundation

private enum HTTPStatus {
    static let badRequest = 400
    static let unauthorized = 401
    static let forbidden = 403
    static let notFound = 404
    static let conflict = 409
    static let badGateway = 502
    static let serviceUnavailable = 503
    static let gatewayTimeout = 504
}

private enum LoyaltyErrorCode {
    static let alreadyRegistered = "already_registered"
    static let alreadyLinked = "already_linked"
    static let notFound = "not_found"
    static let invalidCode = "invalid_code"
    static let invalidData = "invalid_data"
    static let badRequest = "bad_request"
}

/// Maps an HTTP failure onto `LoyaltyCardError`.
///
/// Analytics strings stay `notFound`, `alreadyClaimed`, `alreadyLinked`,
/// `decoding`, `server`, and `unknown`. There is no `InvalidData` case;
/// a 400 `invalid_data` or `bad_request`, and a body that will not decode,
/// are `.underlying(.decoding)`.
///
/// 401 is the status `NetworkClientImpl` returns after its single refresh.
/// This map does not refresh again. 401 and 403 use
/// `LoyaltyCardError.Underlying.firebaseDatabaseDomain` and
/// `firebasePermissionDeniedCode`. 502, 503, and 504 use that domain and
/// `firebaseUnavailableCode`.
extension NetworkError {
    func toLoyaltyCardError() -> LoyaltyCardError {
        switch self {
        case .decodingFailed, .invalidResponse:
            return .underlying(.decoding)
        case .statusCode(let status, let data):
            return mapStatus(status, data)
        case .invalidURL, .unknown:
            return .underlying(.unknown)
        }
    }

    /// `404` whose envelope code is `not_found`. Any other 404 is not this case.
    func isLoyaltyNotFound() -> Bool {
        guard case .statusCode(let status, let data) = self else { return false }
        return status == HTTPStatus.notFound && loyaltyErrorCode(in: data) == LoyaltyErrorCode.notFound
    }
}

private func mapStatus(_ status: Int, _ data: Data) -> LoyaltyCardError {
    let code = loyaltyErrorCode(in: data)
    switch status {
    case HTTPStatus.unauthorized, HTTPStatus.forbidden:
        return permissionDenied()
    case HTTPStatus.badGateway, HTTPStatus.serviceUnavailable, HTTPStatus.gatewayTimeout:
        return unavailable()
    case HTTPStatus.conflict:
        switch code {
        case LoyaltyErrorCode.alreadyRegistered:
            return .alreadyClaimed
        case LoyaltyErrorCode.alreadyLinked:
            return .alreadyLinked
        default:
            return .underlying(.unknown)
        }
    case HTTPStatus.notFound:
        switch code {
        case LoyaltyErrorCode.notFound:
            return .notFound
        default:
            return .underlying(.unknown)
        }
    case HTTPStatus.badRequest:
        switch code {
        case LoyaltyErrorCode.invalidCode:
            return .notFound
        case LoyaltyErrorCode.invalidData, LoyaltyErrorCode.badRequest:
            return .underlying(.decoding)
        default:
            return .underlying(.unknown)
        }
    default:
        // 405, 429, and any other status have no loyalty category.
        return .underlying(.unknown)
    }
}

private func permissionDenied() -> LoyaltyCardError {
    .underlying(.database(
        domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
        code: LoyaltyCardError.Underlying.firebasePermissionDeniedCode
    ))
}

private func unavailable() -> LoyaltyCardError {
    .underlying(.database(
        domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
        code: LoyaltyCardError.Underlying.firebaseUnavailableCode
    ))
}

/// `error.code` from the JSON envelope, or nil when the body has none.
private func loyaltyErrorCode(in data: Data) -> String? {
    guard !data.isEmpty,
          let envelope = try? JSONDecoder().decode(LoyaltyErrorEnvelope.self, from: data),
          let code = envelope.error?.code,
          !code.isEmpty else {
        return nil
    }
    return code
}

private struct LoyaltyErrorEnvelope: Decodable {
    struct Body: Decodable {
        let code: String?
    }

    let error: Body?
}
