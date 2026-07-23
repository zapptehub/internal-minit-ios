/// Every method takes a `file` parameter — callers pass `#fileID` explicitly so
/// conforming loggers (e.g. the console adapter added in Task 5.3) can report
/// where the event was actually triggered, rather than their own adapter file.
/// This can't be a protocol-extension default value: a default-valued
/// extension method with the same signature as a protocol requirement causes
/// infinite recursion at runtime for any conformance that doesn't override it,
/// and even for ones that do, `#fileID` would resolve to this file rather than
/// the real call site. Mirror of `LoginAnalyticsTracking` /
/// `StartAnalyticsTracking`.
///
/// Call sites are wired as each screen lands in Phase 4 — this protocol is
/// stubbed early so analytics is never a late bolt-on.
public protocol OnboardingAnalyticsTracking: Sendable {
    // MARK: Screen views

    func trackNameScreenViewed(file: String)
    func trackLanguageScreenViewed(file: String)
    func trackLoyaltyDecisionScreenViewed(file: String)
    func trackCreatingCardScreenViewed(file: String)
    func trackScannerScreenViewed(file: String)
    func trackProcessingScanScreenViewed(file: String)
    func trackManualCardEntryScreenViewed(file: String)

    // MARK: Validation / selection

    /// Fired when Continue is tapped on the name step with an empty/invalid name.
    func trackNameValidationFailed(file: String)
    /// Fired when a language row is tapped (locale switches immediately).
    func trackLanguageSelected(languageCode: String, file: String)
    /// Fired when a loyalty-decision row is tapped (`newCustomer` / `existingCard`).
    func trackLoyaltyBranchSelected(branch: String, file: String)

    // MARK: Create / claim

    func trackCreateCardAttempted(file: String)
    func trackCreateCardSucceeded(file: String)
    func trackCreateCardFailed(reason: String, file: String)
    func trackClaimCardAttempted(source: String, file: String)
    func trackClaimCardSucceeded(source: String, file: String)
    func trackClaimCardFailed(reason: String, source: String, file: String)

    // MARK: Scanner / permissions

    func trackCameraPermissionRequested(file: String)
    func trackCameraPermissionGranted(file: String)
    func trackCameraPermissionDenied(file: String)
    func trackOpenSettingsTapped(file: String)
    func trackManualEntryChosen(file: String)
    func trackQRCodeScanned(file: String)

    // MARK: Retry / resume / completion

    func trackRetryTapped(step: String, file: String)
    func trackOnboardingResumed(step: String, file: String)
    func trackOnboardingCompleted(file: String)
    /// Fired when "Enter Minit" is tapped on the terminal success screen.
    func trackEnterMinitTapped(file: String)
}
