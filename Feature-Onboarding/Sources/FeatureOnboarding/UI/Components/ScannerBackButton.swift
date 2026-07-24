import SwiftUI
import DesignSystem

/// Full-screen-camera-only back button — thin wrapper around
/// `DSButton(type: .glass, icon: .miniArrowLeft, widthStyle: .icon)`, same pattern as
/// `OnboardingBackButton`. Uses the frosted-glass `.glass` type instead of the light
/// `.social` type used everywhere else, since a solid near-white button would clash with
/// the live camera feed (Task 2.1 decision: "an intentional variant for the camera
/// context"). Uses the same branded `miniArrowLeft` glyph as every other back affordance
/// in the flow — only the background differs here.
struct ScannerBackButton: View {
    let action: () -> Void

    var body: some View {
        DSButton(
            title: "",
            type: .glass,
            icon: .miniArrowLeft,
            iconSize: 20,
            heightStyle: .large,
            widthStyle: .icon,
            accessibilityLabel: String(localized: "onboarding.a11y.back", bundle: .module),
            action: action
        )
    }
}

#Preview("ScannerBackButton") {
    ScannerBackButton(action: {})
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black)
}
