import SwiftUI
import DesignSystem

/// Bottom CTA row for gradient onboarding screens: optional circular back + expanded
/// black Continue/`Enter Minit` pill. Disabled CTAs sit at 60% opacity so `#F2F2F2`
/// blends into the gradient (Task 1.1 decision).
struct OnboardingBottomBar: View {
    let primaryTitle: String
    let isPrimaryEnabled: Bool
    var isPrimaryLoading: Bool = false
    var showsBack: Bool = false
    let onPrimary: () -> Void
    var onBack: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: DSConstant.xLarge.value) {
            if showsBack, let onBack {
                OnboardingBackButton(action: onBack)
            }

            DSButton(
                title: primaryTitle,
                type: .tertiary,
                isEnabled: isPrimaryEnabled,
                isLoading: isPrimaryLoading,
                action: onPrimary
            )
            .opacity(isPrimaryEnabled || isPrimaryLoading ? 1 : 0.6)
        }
    }
}

#Preview("OnboardingBottomBar — continue only") {
    OnboardingBottomBar(
        primaryTitle: "Continue",
        isPrimaryEnabled: false,
        onPrimary: {}
    )
    .padding()
    .background(DSColor.Background.Button.primary)
}

#Preview("OnboardingBottomBar — back + continue") {
    OnboardingBottomBar(
        primaryTitle: "Continue",
        isPrimaryEnabled: true,
        showsBack: true,
        onPrimary: {},
        onBack: {}
    )
    .padding()
    .background(DSColor.Background.Button.primary)
}
