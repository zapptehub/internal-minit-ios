import Foundation
import FirebaseAuth

/// Classifies Firebase Auth errors that mean the persisted identity is permanently
/// invalid (revoked / disabled / deleted) rather than temporarily unreachable.
///
/// Extracted from `FirebaseAuthApiImpl` so the "treat as signed out" mapping can be
/// unit-tested without a live Firebase Auth session.
enum AuthSessionErrorClassifier {
    static func isRevokedSessionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == AuthErrors.domain else { return false }
        let revokedCodes: Set<Int> = [
            AuthErrorCode.userTokenExpired.rawValue,
            AuthErrorCode.userDisabled.rawValue,
            AuthErrorCode.userNotFound.rawValue,
            AuthErrorCode.invalidUserToken.rawValue
        ]
        return revokedCodes.contains(nsError.code)
    }
}
