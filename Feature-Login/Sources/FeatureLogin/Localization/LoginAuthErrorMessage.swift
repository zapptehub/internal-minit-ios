import Foundation
import DataAuth

/// User-facing copy for a failed auth operation.
///
/// Text is Android's `login_error_*` catalog (`LoginErrorStringRes.kt`). Invalid email
/// shares the translated validation string.
enum LoginAuthErrorMessage {
    static func message(for error: Error, locale: Locale) -> String {
        message(for: AuthOperationError(error), locale: locale)
    }

    static func message(for operation: AuthOperationError, locale: Locale) -> String {
        LoginLocalizedString.string(key(for: operation), locale: locale)
    }

    private static func key(for operation: AuthOperationError) -> String {
        switch operation {
        case .invalidCredentials:
            "login.error.invalidCredentials"
        case .invalidEmail:
            "login.error.invalidEmail"
        case .emailAlreadyInUse:
            "login.error.emailAlreadyInUse"
        case .weakPassword:
            "login.error.weakPassword"
        case .accountDisabled:
            "login.error.accountDisabled"
        case .network:
            "login.error.network"
        case .tooManyRequests:
            "login.error.tooManyRequests"
        case .unexpected:
            "login.error.unexpected"
        }
    }
}
