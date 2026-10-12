import Foundation
import FirebaseAuth

/// Provider-independent auth failure. Login localizes this instead of showing
/// Firebase's English `localizedDescription`.
///
/// Same cases as Android `Exception.toAuthError()` in `FirebaseAuthApiImpl.kt`.
/// Server `INVALID_LOGIN_CREDENTIALS` has no separate `AuthErrorCode`; the iOS
/// SDK delivers it as `.invalidCredential`. Android's `AuthError.InvalidResponse`
/// is not a Firebase code; it and every unmapped failure are `.unexpected`.
public enum AuthOperationError: Equatable, Error {
    case invalidCredentials
    case invalidEmail
    case emailAlreadyInUse
    case weakPassword
    case accountDisabled
    case network
    case tooManyRequests
    case unexpected

    /// Classifies `error`, including an auth `NSError` nested as `NSUnderlyingError`.
    public init(_ error: Error) {
        if let operation = error as? AuthOperationError {
            self = operation
            return
        }
        self = Self.classify(error, remainingDepth: 8) ?? .unexpected
    }

    private static func classify(_ error: Error, remainingDepth: Int) -> AuthOperationError? {
        guard remainingDepth > 0 else { return nil }
        if let code = error as? AuthErrorCode {
            return map(code)
        }
        let nsError = error as NSError
        if nsError.domain == AuthErrors.domain {
            guard let code = AuthErrorCode(rawValue: nsError.code) else { return .unexpected }
            return map(code)
        }
        guard let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error else { return nil }
        if (underlying as NSError) === nsError { return nil }
        return classify(underlying, remainingDepth: remainingDepth - 1)
    }

    private static func map(_ code: AuthErrorCode) -> AuthOperationError {
        switch code {
        case .wrongPassword,
             .invalidCredential,
             .userNotFound,
             .invalidUserToken,
             .userTokenExpired:
            return .invalidCredentials
        case .invalidEmail:
            return .invalidEmail
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .weakPassword:
            return .weakPassword
        case .userDisabled:
            return .accountDisabled
        case .networkError:
            return .network
        case .tooManyRequests:
            return .tooManyRequests
        default:
            return .unexpected
        }
    }
}
