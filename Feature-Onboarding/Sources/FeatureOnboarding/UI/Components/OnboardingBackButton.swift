import SwiftUI
import DesignSystem

/// Circular back affordance for gradient onboarding screens — thin wrapper around
/// `DSButton(type: .social, icon: .miniArrowLeft, widthStyle: .icon)` so every call site
/// shares one visual.
struct OnboardingBackButton: View {
    let action: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        DSButton(
            title: "",
            type: .social,
            icon: .miniArrowLeft,
            widthStyle: .icon,
            accessibilityLabel: OnboardingLocalizedString.string("onboarding.a11y.back", locale: locale),
            action: action
        )
    }
}

#Preview("OnboardingBackButton") {
    OnboardingBackButton(action: {})
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DSColor.Background.Button.primary)
}
