import SwiftUI
import DesignSystem

/// Temporary stand-in until Task 4.1 replaces this with the resumable state
/// machine and NavigationStack. Exists so the package builds, previews work,
/// and Task 5.2 can wire `FeatureOnboarding.createScreen(...)` without waiting
/// for the full UI.
struct OnboardingPlaceholderScreen: View {
    let userId: String
    let analytics: OnboardingAnalyticsTracking
    let onCompleted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.large.value) {
            Text(String(localized: "onboarding.placeholder.headline", bundle: .module))
                .typography(.headingLargeSemibold)
                .foregroundColor(DSColor.Text.heading)

            Text(String(localized: "onboarding.placeholder.subtitle", bundle: .module))
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.secondary)

            DSButton(
                title: String(localized: "onboarding.button.enterMinit", bundle: .module),
                type: .tertiary
            ) {
                analytics.trackEnterMinitTapped(file: #fileID)
                analytics.trackOnboardingCompleted(file: #fileID)
                onCompleted()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .defaultSidePadding()
        .padding(.top, DSConstant.xLarge.value)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
        .onAppear {
            analytics.trackOnboardingResumed(step: "placeholder", file: #fileID)
        }
    }
}

#Preview("OnboardingPlaceholderScreen") {
    OnboardingPlaceholderScreen(
        userId: "preview-user",
        analytics: PreviewOnboardingAnalyticsTracking(),
        onCompleted: {}
    )
}
