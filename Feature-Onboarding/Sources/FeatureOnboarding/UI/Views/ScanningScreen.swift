import SwiftUI
import DesignSystem

/// `scanning` step — full-screen black VisionKit camera view with a custom QR
/// reticle overlay, per the Task 1.1 checklist's "Frame C" scanner reference. Distinct
/// from every other onboarding screen: no gradient background, no top progress bar
/// (`OnboardingFlowScreen` hides it specifically for this one step), and its own dark
/// circular back button instead of the shared light one.
///
/// Three states, in priority order:
/// 1. Real camera (`QRScannerView.isSupported && .isAvailable`) — the capture button
///    is decorative; VisionKit auto-detects continuously.
/// 2. Simulator (`QRScannerView.isRunningInSimulator`, always true in the Preview
///    canvas too) — no real camera exists, so the same reticle chrome renders over
///    plain black and the capture button becomes real: tapping it simulates a
///    successful scan of the deterministic dev test card (Task 3.3), letting the
///    scan → claim path be exercised end to end without a physical device.
/// 3. A genuinely unsupported real device — the actual manual-entry fallback
///    (`ScannerPermissionScreen` already routes around this step for that case, so
///    reaching this branch on a real device would only happen defensively, e.g. a
///    persisted `step` from an older build).
struct ScanningScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack {
            // Only the black backdrop (and the live camera feed below, which sets its
            // own `.ignoresSafeArea()`) should bleed to the true screen edges — chrome
            // like the back button and capture button needs to respect the safe area
            // so it lands where a nav-bar back button normally would, not under the
            // status bar/notch.
            Color.black.ignoresSafeArea()

            if QRScannerView.isSupported && QRScannerView.isAvailable {
                QRScannerView(onScan: { code in
                    viewModel.didScanCode(code)
                })
                .ignoresSafeArea()
                .accessibilityLabel(OnboardingLocalizedString.string("onboarding.a11y.scannerCamera", locale: locale))

                overlay(simulatedScanAction: nil)
            } else if QRScannerView.isRunningInSimulator {
                overlay(simulatedScanAction: {
                    viewModel.didScanCode("MINIT-340ECFF7FF")
                })
            } else {
                unsupportedFallback
            }
        }
        .onAppear {
            analytics.trackScannerScreenViewed(file: #fileID)
        }
    }

    /// Shared reticle + caption + capture-button chrome for both the real-camera and
    /// Simulator states. `simulatedScanAction` is `nil` on a real device (button
    /// stays decorative, per Task 1.1) or the closure that fires a mocked scan on
    /// the Simulator.
    ///
    /// Laid out via `GeometryReader` rather than a single `VStack` with two `Spacer`s:
    /// the back row and capture button have different heights, so two `Spacer`s would
    /// split the *remaining* space evenly around the reticle+caption+hint block as a
    /// whole — pushing the reticle itself above true center (since the caption/hint
    /// text hangs below it, but nothing hangs above). Instead, the reticle is pinned
    /// to the exact vertical center of the available (safe-area-respecting) space,
    /// and the caption/hint sit a fixed gap below its bottom edge, independent of
    /// their own (dynamic, possibly multi-line) height.
    private func overlay(simulatedScanAction: (() -> Void)?) -> some View {
        Group {
            if dynamicTypeSize > .large {
            // Keep the reticle in the space above the caption so the grown
            // lines do not run through the brackets or the capture button.
            VStack(spacing: DSConstant.medium.value) {
                ZStack {
                    ReticleShape()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: Self.reticleSize, height: Self.reticleSize)
                        .accessibilityHidden(true)
                    backRow
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                captionBlock(simulatedScanAction: simulatedScanAction, height: 0)
            }
        } else {
            GeometryReader { proxy in
                ZStack {
                    ReticleShape()
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                        .frame(width: Self.reticleSize, height: Self.reticleSize)
                        .accessibilityHidden(true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    captionBlock(simulatedScanAction: simulatedScanAction, height: proxy.size.height)

                    backRow
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                    captureButton(action: simulatedScanAction)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
        }
    }

    @ViewBuilder
    private func captionBlock(simulatedScanAction: (() -> Void)?, height: CGFloat) -> some View {
        let captions = VStack(spacing: DSConstant.small.value) {
            Text(OnboardingLocalizedString.string("onboarding.scanner.caption", locale: locale))
                .typography(.paragraphRegular)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .uncompressedWhenTextIsLarge()

            if simulatedScanAction != nil {
                // Simulator-only dev hint — this branch never compiles into a
                // device/App Store build, so it's deliberately not localized
                // like the real user-facing caption above.
                Text("Simulator — tap the button below to simulate a scan.")
                    .typography(.uiRegular)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .uncompressedWhenTextIsLarge()
            }
        }
        .padding(.horizontal, DSConstant.xLarge.value)

        if dynamicTypeSize > .large {
            // The reticle caption used to sit on a fixed offset and ran
            // through the capture button once the lines grew.
            VStack(spacing: DSConstant.medium.value) {
                captions
                captureButton(action: simulatedScanAction)
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
        } else {
            captions
                .padding(.top, height / 2 + Self.reticleSize / 2 + DSConstant.xLarge.value)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func captureButton(action: (() -> Void)?) -> some View {
        // Decorative-only on a real device (Task 1.1: "kept as decoration/secondary
        // affordance" — VisionKit auto-detects continuously, no shutter tap needed);
        // functional only in the Simulator branch above, which passes a non-nil
        // `action`.
        DSButton(
            title: "",
            type: .primary,
            icon: .minitCamera,
            iconSize: 24,
            heightStyle: .xLarge,
            widthStyle: .icon,
            accessibilityLabel: action == nil
                ? nil
                : OnboardingLocalizedString.string("onboarding.a11y.simulateScan", locale: locale),
            action: action ?? {}
        )
        .allowsHitTesting(action != nil)
        .accessibilityHidden(action == nil)
        .padding(.bottom, DSConstant.xLarge.value)
    }

    private var unsupportedFallback: some View {
        VStack(spacing: DSConstant.large.value) {
            backRow

            Spacer()

            Text(OnboardingLocalizedString.string("onboarding.scanner.unsupported", locale: locale))
                .typography(.paragraphRegular)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DSConstant.xLarge.value)

            DSButton(
                title: OnboardingLocalizedString.string("onboarding.alert.action.enterManually", locale: locale),
                type: .tertiary,
                action: { viewModel.chooseManualCardEntry() }
            )
            .padding(.horizontal, DSConstant.large.value)

            Spacer()
        }
    }

    private var backRow: some View {
        HStack {
            ScannerBackButton(action: { viewModel.goBack() })
            Spacer()
        }
        .padding(.top, DSConstant.medium.value)
        .padding(.horizontal, DSConstant.large.value)
    }

    private static let reticleSize: CGFloat = 280
}

/// Four independent corner brackets forming a square target reticle — VisionKit's own
/// highlighting/guidance UI is turned off in `QRScannerView`, so this is the only
/// scan-target affordance on screen (Task 1.1: "four white corner brackets"). Each
/// bracket is two straight segments joined by a quarter-circle arc rather than a sharp
/// right angle, per Figma's rounded-corner reticle.
private struct ReticleShape: Shape {
    var cornerLength: CGFloat = 44
    var cornerRadius: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length = min(cornerLength, min(rect.width, rect.height) / 2)
        let radius = min(cornerRadius, length)

        // Each corner: straight segment in → quarter-circle arc around the curved
        // corner → straight segment out. All four arcs use `clockwise: false`
        // (counter-clockwise in UIKit's y-down coordinate system) so the curve bows
        // *outward* into the corner rather than into the reticle's interior. Each
        // corner is the previous one rotated 90°, so start/end angles advance by
        // 90° each time.

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
            radius: radius,
            startAngle: .degrees(270),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
    }
}

#Preview("ScanningScreen — simulated scan (Simulator)") {
    // `QRScannerView.isRunningInSimulator` is always `true` in the Preview canvas
    // (it builds for the Simulator target), so this preview exercises the same
    // functional-capture-button branch a Simulator run does — there is no way to
    // preview the real-camera state, and the real-unsupported-device fallback can
    // only be exercised on an actual device.
    ScanningScreen(
        viewModel: PreviewOnboarding.makeViewModel(),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}
