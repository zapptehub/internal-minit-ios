import FeatureOnboarding

/// Recording mock for unit tests. Lives in a separate product so Feature-Onboarding
/// itself doesn't depend on XCTest, matching `LoginTestUtilities`.
public final class MockOnboardingAnalyticsTracking: OnboardingAnalyticsTracking {
    public var trackNameScreenViewedCalled = false
    public var trackLanguageScreenViewedCalled = false
    public var trackLoyaltyDecisionScreenViewedCalled = false
    public var trackCreatingCardScreenViewedCalled = false
    public var trackScannerScreenViewedCalled = false
    public var trackScanReviewScreenViewedCalled = false
    public var trackManualCardEntryScreenViewedCalled = false
    public var trackNameValidationFailedCalled = false
    public var trackLanguageSelectedCalled = false
    public var trackLanguageSelectedCode: String?
    public var trackLoyaltyBranchSelectedCalled = false
    public var trackLoyaltyBranchSelectedBranch: String?
    public var trackCreateCardAttemptedCalled = false
    public var trackCreateCardSucceededCalled = false
    public var trackCreateCardFailedCalled = false
    public var trackCreateCardFailedReason: String?
    public var trackClaimCardAttemptedCalled = false
    public var trackClaimCardAttemptedSource: String?
    public var trackClaimCardSucceededCalled = false
    public var trackClaimCardSucceededSource: String?
    public var trackClaimCardFailedCalled = false
    public var trackClaimCardFailedReason: String?
    public var trackClaimCardFailedSource: String?
    public var trackCameraPermissionRequestedCalled = false
    public var trackCameraPermissionGrantedCalled = false
    public var trackCameraPermissionDeniedCalled = false
    public var trackOpenSettingsTappedCalled = false
    public var trackManualEntryChosenCalled = false
    public var trackQRCodeScannedCalled = false
    public var trackRetryTappedCalled = false
    public var trackRetryTappedStep: String?
    public var trackOnboardingResumedCalled = false
    public var trackOnboardingResumedStep: String?
    public var trackOnboardingCompletedCalled = false
    public var trackEnterMinitTappedCalled = false

    public init() {}

    public func trackNameScreenViewed(file: String = #fileID) {
        trackNameScreenViewedCalled = true
    }

    public func trackLanguageScreenViewed(file: String = #fileID) {
        trackLanguageScreenViewedCalled = true
    }

    public func trackLoyaltyDecisionScreenViewed(file: String = #fileID) {
        trackLoyaltyDecisionScreenViewedCalled = true
    }

    public func trackCreatingCardScreenViewed(file: String = #fileID) {
        trackCreatingCardScreenViewedCalled = true
    }

    public func trackScannerScreenViewed(file: String = #fileID) {
        trackScannerScreenViewedCalled = true
    }

    public func trackScanReviewScreenViewed(file: String = #fileID) {
        trackScanReviewScreenViewedCalled = true
    }

    public func trackManualCardEntryScreenViewed(file: String = #fileID) {
        trackManualCardEntryScreenViewedCalled = true
    }

    public func trackNameValidationFailed(file: String = #fileID) {
        trackNameValidationFailedCalled = true
    }

    public func trackLanguageSelected(languageCode: String, file: String = #fileID) {
        trackLanguageSelectedCalled = true
        trackLanguageSelectedCode = languageCode
    }

    public func trackLoyaltyBranchSelected(branch: String, file: String = #fileID) {
        trackLoyaltyBranchSelectedCalled = true
        trackLoyaltyBranchSelectedBranch = branch
    }

    public func trackCreateCardAttempted(file: String = #fileID) {
        trackCreateCardAttemptedCalled = true
    }

    public func trackCreateCardSucceeded(file: String = #fileID) {
        trackCreateCardSucceededCalled = true
    }

    public func trackCreateCardFailed(reason: String, file: String = #fileID) {
        trackCreateCardFailedCalled = true
        trackCreateCardFailedReason = reason
    }

    public func trackClaimCardAttempted(source: String, file: String = #fileID) {
        trackClaimCardAttemptedCalled = true
        trackClaimCardAttemptedSource = source
    }

    public func trackClaimCardSucceeded(source: String, file: String = #fileID) {
        trackClaimCardSucceededCalled = true
        trackClaimCardSucceededSource = source
    }

    public func trackClaimCardFailed(reason: String, source: String, file: String = #fileID) {
        trackClaimCardFailedCalled = true
        trackClaimCardFailedReason = reason
        trackClaimCardFailedSource = source
    }

    public func trackCameraPermissionRequested(file: String = #fileID) {
        trackCameraPermissionRequestedCalled = true
    }

    public func trackCameraPermissionGranted(file: String = #fileID) {
        trackCameraPermissionGrantedCalled = true
    }

    public func trackCameraPermissionDenied(file: String = #fileID) {
        trackCameraPermissionDeniedCalled = true
    }

    public func trackOpenSettingsTapped(file: String = #fileID) {
        trackOpenSettingsTappedCalled = true
    }

    public func trackManualEntryChosen(file: String = #fileID) {
        trackManualEntryChosenCalled = true
    }

    public func trackQRCodeScanned(file: String = #fileID) {
        trackQRCodeScannedCalled = true
    }

    public func trackRetryTapped(step: String, file: String = #fileID) {
        trackRetryTappedCalled = true
        trackRetryTappedStep = step
    }

    public func trackOnboardingResumed(step: String, file: String = #fileID) {
        trackOnboardingResumedCalled = true
        trackOnboardingResumedStep = step
    }

    public func trackOnboardingCompleted(file: String = #fileID) {
        trackOnboardingCompletedCalled = true
    }

    public func trackEnterMinitTapped(file: String = #fileID) {
        trackEnterMinitTappedCalled = true
    }
}
