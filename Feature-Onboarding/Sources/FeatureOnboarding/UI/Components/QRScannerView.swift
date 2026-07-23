import SwiftUI
import VisionKit

/// Thin `UIViewControllerRepresentable` bridge to `VisionKit.DataScannerViewController`,
/// configured for continuous QR auto-detection (Task 1.1: "auto-detect... no manual
/// shutter required"). Camera permission is assumed already granted by the time this
/// view appears — `ScannerPermissionScreen` owns the permission flow and only advances
/// to `.scanning` once authorized; this view still no-ops instead of crashing if that
/// invariant is somehow violated (`updateUIViewController` guards on `isAvailable`).
///
/// VisionKit's own highlighting/guidance UI is disabled — `ScanningScreen` draws its
/// own reticle + caption overlay per the Task 1.1 checklist, so only one visual
/// affordance is ever on screen.
struct QRScannerView: UIViewControllerRepresentable {
    /// Called at most once per screen appearance — the coordinator latches after the
    /// first recognized code so a burst of frames matching the same physical code
    /// can't invoke this twice before `OnboardingViewModel.didScanCode(_:)` (which has
    /// its own second guard) moves `step` away from `.scanning`.
    let onScan: (String) -> Void

    /// Hardware + OS capability check — `false` on the Simulator (no camera) and on
    /// devices too old/unsupported for `DataScannerViewController`. Callers must check
    /// this before presenting `QRScannerView` at all and fall back to manual entry.
    static var isSupported: Bool {
        DataScannerViewController.isSupported
    }

    /// Whether scanning can actually start *right now* — folds current camera
    /// authorization/availability on top of `isSupported`, catching a race like
    /// permission being revoked while the app was backgrounded.
    static var isAvailable: Bool {
        DataScannerViewController.isAvailable
    }

    /// `true` only when running in the iOS Simulator — this is a compile-time check
    /// (`targetEnvironment(simulator)`), so it can never evaluate `true` in a real
    /// device/App Store build. The Simulator has no camera, so `isSupported`/
    /// `isAvailable` are always `false` there; `ScannerPermissionScreen` and
    /// `ScanningScreen` use this flag to offer a mocked scan in that specific case
    /// instead of skipping straight to manual entry, which stays the only fallback
    /// for a genuinely unsupported real *device*.
    static var isRunningInSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: false,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {
        guard QRScannerView.isAvailable, !controller.isScanning else { return }
        try? controller.startScanning()
    }

    static func dismantleUIViewController(_ controller: DataScannerViewController, coordinator: Coordinator) {
        controller.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        /// Duplicate-scan suppression: latched `true` on the first recognized QR so
        /// later delegate callbacks (more frames of the same code, recognized before
        /// scanning actually stops) are ignored.
        private var hasScanned = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasScanned else { return }
            guard let payload = addedItems.compactMap(Self.payload).first else { return }

            hasScanned = true
            dataScanner.stopScanning()
            onScan(payload)
        }

        private static func payload(for item: RecognizedItem) -> String? {
            guard case .barcode(let barcode) = item else { return nil }
            return barcode.payloadStringValue
        }
    }
}

#Preview("QRScannerView") {
    // `DataScannerViewController.isAvailable` is always `false` in the Simulator/
    // Preview canvas (no real camera), so `updateUIViewController` never actually
    // calls `startScanning()` here — this just confirms the representable itself
    // constructs without crashing. `ScanningScreen`'s own preview is what exercises
    // the real unsupported-device fallback UI.
    QRScannerView(onScan: { _ in })
        .background(Color.black)
        .ignoresSafeArea()
}
