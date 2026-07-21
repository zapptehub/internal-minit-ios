/// `scannerPermission` step (existing-card branch) — camera authorization only.
/// Actually recognizing a code and claiming it is the Claim section's job
/// (`OnboardingViewModel+Claim.swift`); this file stops at handing off to `scanning`
/// or `manualCardEntry`.
extension OnboardingViewModel {
    public func requestingCameraPermission() {
        analytics.trackCameraPermissionRequested(file: #fileID)
    }

    public func cameraPermissionGranted() {
        analytics.trackCameraPermissionGranted(file: #fileID)
        advance(via: .cameraPermissionGranted)
    }

    public func cameraPermissionDenied() {
        analytics.trackCameraPermissionDenied(file: #fileID)
        activeAlert = .cameraPermissionDenied
    }

    public func didTapOpenSettings() {
        // Opening `UIApplication.openSettingsURLString` is a UIKit concern the scanner
        // screen (Task 4.4) handles directly — this view model stays UIKit-free.
        analytics.trackOpenSettingsTapped(file: #fileID)
        activeAlert = nil
    }

    /// Matrix: canceling the camera-permission alert returns to `loyaltyDecision`
    /// with the existing-card row still selected. Clears the alert and uses the
    /// shared back path so destination + checkpoint stay consistent with `goBack()`.
    public func dismissCameraPermissionAlert() {
        guard activeAlert == .cameraPermissionDenied else { return }
        goBack()
    }

    public func chooseManualCardEntry() {
        analytics.trackManualEntryChosen(file: #fileID)
        activeAlert = nil
        advance(via: .manualCardEntryChosen)
    }
}
