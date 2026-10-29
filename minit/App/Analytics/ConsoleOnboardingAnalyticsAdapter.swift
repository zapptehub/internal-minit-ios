import CoreLogging
import FeatureOnboarding

final class ConsoleOnboardingAnalyticsAdapter: OnboardingAnalyticsTracking {
    private let logger = AppLogger(subsystem: "com.minit.app", category: "Analytics")

    private func report(_ message: String, file: String) {
        logger.info(message, file: file)
        AppLogger.forward(message)
    }

    // MARK: Screen views

    func trackNameScreenViewed(file: String) {
        report("Analytics: onboarding_name_screen_viewed", file: file)
    }

    func trackLanguageScreenViewed(file: String) {
        report("Analytics: onboarding_language_screen_viewed", file: file)
    }

    func trackLoyaltyDecisionScreenViewed(file: String) {
        report("Analytics: onboarding_loyalty_decision_screen_viewed", file: file)
    }

    func trackCreatingCardScreenViewed(file: String) {
        report("Analytics: onboarding_creating_card_screen_viewed", file: file)
    }

    func trackScannerScreenViewed(file: String) {
        report("Analytics: onboarding_scanner_screen_viewed", file: file)
    }

    func trackProcessingScanScreenViewed(file: String) {
        report("Analytics: onboarding_processing_scan_screen_viewed", file: file)
    }

    func trackManualCardEntryScreenViewed(file: String) {
        report("Analytics: onboarding_manual_card_entry_screen_viewed", file: file)
    }

    // MARK: Validation / selection

    func trackNameValidationFailed(file: String) {
        report("Analytics: onboarding_name_validation_failed", file: file)
    }

    func trackLanguageSelected(languageCode: String, file: String) {
        report("Analytics: onboarding_language_selected — \(languageCode)", file: file)
    }

    func trackLoyaltyBranchSelected(branch: String, file: String) {
        report("Analytics: onboarding_loyalty_branch_selected — \(branch)", file: file)
    }

    // MARK: Create / claim

    func trackCreateCardAttempted(file: String) {
        report("Analytics: onboarding_create_card_attempted", file: file)
    }

    func trackCreateCardSucceeded(file: String) {
        report("Analytics: onboarding_create_card_succeeded", file: file)
    }

    func trackCreateCardFailed(reason: String, file: String) {
        report("Analytics: onboarding_create_card_failed — \(reason)", file: file)
    }

    func trackClaimCardAttempted(source: String, file: String) {
        report("Analytics: onboarding_claim_card_attempted — \(source)", file: file)
    }

    func trackClaimCardSucceeded(source: String, file: String) {
        report("Analytics: onboarding_claim_card_succeeded — \(source)", file: file)
    }

    func trackClaimCardFailed(reason: String, source: String, file: String) {
        report("Analytics: onboarding_claim_card_failed — \(source) — \(reason)", file: file)
    }

    // MARK: Scanner / permissions

    func trackCameraPermissionRequested(file: String) {
        report("Analytics: onboarding_camera_permission_requested", file: file)
    }

    func trackCameraPermissionGranted(file: String) {
        report("Analytics: onboarding_camera_permission_granted", file: file)
    }

    func trackCameraPermissionDenied(file: String) {
        report("Analytics: onboarding_camera_permission_denied", file: file)
    }

    func trackOpenSettingsTapped(file: String) {
        report("Analytics: onboarding_open_settings_tapped", file: file)
    }

    func trackManualEntryChosen(file: String) {
        report("Analytics: onboarding_manual_entry_chosen", file: file)
    }

    func trackQRCodeScanned(file: String) {
        report("Analytics: onboarding_qr_code_scanned", file: file)
    }

    // MARK: Retry / resume / completion

    func trackRetryTapped(step: String, file: String) {
        report("Analytics: onboarding_retry_tapped — \(step)", file: file)
    }

    func trackOnboardingResumed(step: String, file: String) {
        report("Analytics: onboarding_resumed — \(step)", file: file)
    }

    func trackOnboardingCompleted(file: String) {
        report("Analytics: onboarding_completed", file: file)
    }

    func trackEnterMinitTapped(file: String) {
        report("Analytics: onboarding_enter_minit_tapped", file: file)
    }
}
