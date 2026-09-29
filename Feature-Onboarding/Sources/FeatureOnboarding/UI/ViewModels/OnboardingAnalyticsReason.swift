import DataLoyaltyCard

/// Stable create-card and claim-card failure codes.
///
/// These raw values must stay identical to Android `OnboardingAnalyticsReason.code`:
/// `notFound`, `alreadyClaimed`, `alreadyLinked`, `decoding`, `server`, `unknown`.
///
/// `network` is omitted. Android Realtime Database reports `NETWORK_ERROR` and
/// `DISCONNECTED`, but iOS folds disconnect, offline, and generic `failed` into
/// `NSError` code `9999` (or `com.firebase.core` / `1` for a failed `getData()`
/// with an empty cache). Sharing a network code would require matching message
/// text. `timeout` is omitted: neither SDK surfaces a timeout status on this
/// path. `URLError.timedOut` does not escape the Realtime Database client.
enum OnboardingAnalyticsReason: String, CaseIterable {
    case notFound
    case alreadyClaimed
    case alreadyLinked
    case decoding
    case server
    case unknown

    /// Fixed code for analytics. Never includes the error message, a path, or an id.
    static func code(for error: Error) -> String {
        guard let loyaltyError = error as? LoyaltyCardError else {
            return Self.unknown.rawValue
        }
        switch loyaltyError {
        case .notFound:
            return Self.notFound.rawValue
        case .alreadyClaimed:
            return Self.alreadyClaimed.rawValue
        case .alreadyLinked:
            return Self.alreadyLinked.rawValue
        case .underlying(let failure):
            return code(for: failure).rawValue
        }
    }

    private static func code(for failure: LoyaltyCardError.Underlying) -> OnboardingAnalyticsReason {
        switch failure {
        case .decoding:
            return .decoding
        case .unknown:
            return .unknown
        case .database(let domain, let code):
            // Only the two wire statuses both platforms expose as their own code.
            // Android `OPERATION_FAILED` and iOS status `failed` (code 9999) stay
            // `unknown` because that code is also disconnect and offline.
            let isServer = domain == LoyaltyCardError.Underlying.firebaseDatabaseDomain &&
                (code == LoyaltyCardError.Underlying.firebasePermissionDeniedCode ||
                    code == LoyaltyCardError.Underlying.firebaseUnavailableCode)
            return isServer ? .server : .unknown
        }
    }
}
