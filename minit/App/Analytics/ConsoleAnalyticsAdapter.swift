import CoreLogging
import FeatureLogin

final class ConsoleAnalyticsAdapter: LoginAnalyticsTracking {
    private let logger = AppLogger(subsystem: "com.minit.app", category: "Analytics")

    func trackLoginAttempt(file: String) {
        logger.info("Analytics: login_attempt", file: file)
    }

    func trackLoginSuccess(file: String) {
        logger.info("Analytics: login_success", file: file)
    }

    func trackLoginFailed(reason: String, file: String) {
        logger.info("Analytics: login_failed — \(reason)", file: file)
    }

    func trackAppleSignInTapped(file: String) {
        logger.info("Analytics: login_apple_signin_tapped", file: file)
    }

    func trackGoogleSignInTapped(file: String) {
        logger.info("Analytics: login_google_signin_tapped", file: file)
    }

    func trackForgotPasswordRequested(file: String) {
        logger.info("Analytics: forgot_password_requested", file: file)
    }

    func trackPasswordResetCompleted(file: String) {
        logger.info("Analytics: password_reset_completed", file: file)
    }

    func trackEmailContinueTapped(file: String) {
        logger.info("Analytics: login_email_continue_tapped", file: file)
    }

    func trackForgotPasswordLinkTapped(file: String) {
        logger.info("Analytics: login_forgot_password_link_tapped", file: file)
    }

    func trackSignUpAttempt(file: String) {
        logger.info("Analytics: login_sign_up_attempt", file: file)
    }

    func trackSignUpSuccess(file: String) {
        logger.info("Analytics: login_sign_up_success", file: file)
    }

    func trackSignUpFailed(reason: String, file: String) {
        logger.info("Analytics: login_sign_up_failed — \(reason)", file: file)
    }

    func trackVerificationCodeResent(file: String) {
        logger.info("Analytics: login_verification_code_resent", file: file)
    }

    func trackPasswordChangedBackToLoginTapped(file: String) {
        logger.info("Analytics: login_password_changed_back_to_login_tapped", file: file)
    }
}
