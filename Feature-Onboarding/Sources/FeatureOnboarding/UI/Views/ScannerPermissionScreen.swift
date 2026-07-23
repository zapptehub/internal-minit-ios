import SwiftUI
import AVFoundation
import UIKit
import DesignSystem

/// `scannerPermission` step. Per the Task 1.1 checklist's follow-up #1, no custom
/// pre-permission priming screen is planned — this screen exists only to host the raw
/// OS camera prompt (or the current authorization check on resume) and the
/// denied-fallback alert; it renders the same gradient chrome as `LoyaltyDecisionScreen`
/// underneath so there is no visual flash while that check runs, then advances
/// automatically.
struct ScannerPermissionScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking

    var body: some View {
        OnboardingScaffold(
            subtitle: String(localized: "onboarding.loyalty.subtitle", bundle: .module),
            headline: String(localized: "onboarding.loyalty.headline", bundle: .module),
            primaryTitle: String(localized: "onboarding.button.continue", bundle: .module),
            isPrimaryEnabled: false,
            isPrimaryLoading: true,
            showsBack: true,
            onPrimary: {},
            onBack: { viewModel.goBack() }
        ) {
            Color.clear
        }
        .task {
            await requestAccessIfNeeded()
        }
        .alert(
            String(localized: "onboarding.alert.cameraDenied.title", bundle: .module),
            isPresented: cameraDeniedAlertPresented
        ) {
            Button(String(localized: "onboarding.alert.action.openSettings", bundle: .module)) {
                openSettings()
                viewModel.didTapOpenSettings()
            }
            Button(String(localized: "onboarding.alert.action.enterManually", bundle: .module)) {
                viewModel.chooseManualCardEntry()
            }
            Button(String(localized: "onboarding.alert.action.cancel", bundle: .module), role: .cancel) {
                viewModel.dismissCameraPermissionAlert()
            }
        } message: {
            Text(String(localized: "onboarding.alert.cameraDenied.message", bundle: .module))
        }
    }

    /// Re-checks current authorization on every appearance rather than blindly
    /// re-prompting (matrix's resume rule: "re-check current authorization status
    /// rather than re-prompting blindly, avoids re-showing the OS prompt if the user
    /// already decided while the app was backgrounded"). A genuinely unsupported
    /// real device (below `DataScannerViewController`'s requirements) skips the
    /// camera flow entirely and goes straight to manual entry. The Simulator is
    /// also "unsupported" (no camera hardware at all) but is treated as granted
    /// instead — `ScanningScreen` offers a mocked capture button there so the
    /// scan → claim path stays exercisable without a physical device.
    private func requestAccessIfNeeded() async {
        guard QRScannerView.isSupported else {
            if QRScannerView.isRunningInSimulator {
                viewModel.cameraPermissionGranted()
            } else {
                viewModel.chooseManualCardEntry()
            }
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            viewModel.cameraPermissionGranted()
        case .notDetermined:
            viewModel.requestingCameraPermission()
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if granted {
                viewModel.cameraPermissionGranted()
            } else {
                viewModel.cameraPermissionDenied()
            }
        case .denied, .restricted:
            viewModel.cameraPermissionDenied()
        @unknown default:
            viewModel.cameraPermissionDenied()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var cameraDeniedAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.activeAlert == .cameraPermissionDenied },
            set: { _ in
                // Dismissed only via the explicit buttons above, which already clear
                // (or advance away from) `activeAlert` themselves.
            }
        )
    }
}

#Preview("ScannerPermissionScreen — checking") {
    ScannerPermissionScreen(
        viewModel: PreviewOnboarding.makeViewModel(),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}

#Preview("ScannerPermissionScreen — denied alert") {
    let viewModel = PreviewOnboarding.makeViewModel()
    viewModel.selectBranch(.existingCard)
    viewModel.cameraPermissionDenied()
    return ScannerPermissionScreen(
        viewModel: viewModel,
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}
