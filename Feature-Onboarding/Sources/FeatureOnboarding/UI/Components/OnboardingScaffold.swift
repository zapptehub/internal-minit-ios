import SwiftUI
import DesignSystem

/// Full-bleed orange→cream gradient shell shared by every non-camera onboarding screen:
/// top progress bar, subtitle + headline, content slot, and bottom CTA bar.
///
/// Subtitle is dark and headline is white on every gradient step (matches Figma).
struct OnboardingScaffold<Content: View>: View {
    let progress: Double
    let subtitle: String
    let headline: String
    let primaryTitle: String
    let isPrimaryEnabled: Bool
    var isPrimaryLoading: Bool = false
    var showsBack: Bool = false
    let onPrimary: () -> Void
    var onBack: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgressBar(progress: progress)
                .padding(.top, DSConstant.medium.value)

            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text(subtitle)
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.heading)

                Text(headline)
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.inverse)
                    .tracking(-1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, DSConstant.large.value)

            content()
                .padding(.top, DSConstant.large.value)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            OnboardingBottomBar(
                primaryTitle: primaryTitle,
                isPrimaryEnabled: isPrimaryEnabled,
                isPrimaryLoading: isPrimaryLoading,
                showsBack: showsBack,
                onPrimary: onPrimary,
                onBack: onBack
            )
            .padding(.bottom, DSConstant.medium.value)
        }
        .padding(.horizontal, DSConstant.large.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(gradient.ignoresSafeArea())
    }

    private var gradient: LinearGradient {
        // Tuned to the onboarding mockups: hot orange held through the header,
        // then a long warm peach fade that reaches solid white by ~75%
        // (so the CTA bar sits on clean white, not cream).
        let top = Color(red: 1.0, green: 0.51, blue: 0.0) // #FF8300 — hotter than brand primary
        let mid = DSColor.Background.Button.primary // #FF9A31
        let peach = Color(red: 1.0, green: 0.78, blue: 0.56) // #FFC78F
        let cream = Color(red: 1.0, green: 0.945, blue: 0.88) // #FFF1E0
        return LinearGradient(
            stops: [
                .init(color: top, location: 0),
                .init(color: top, location: 0.12),
                .init(color: mid, location: 0.28),
                .init(color: peach, location: 0.48),
                .init(color: cream, location: 0.65),
                .init(color: .white, location: 0.78),
                .init(color: .white, location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

#Preview("OnboardingScaffold — name step") {
    OnboardingScaffold(
        progress: 0.16,
        subtitle: "Hello! Welcome to Minit",
        headline: "What should I call you?",
        primaryTitle: "Continue",
        isPrimaryEnabled: false,
        onPrimary: {}
    ) {
        Text("Enter your name")
            .font(.system(size: 30))
            .foregroundColor(DSColor.Text.heading.opacity(0.4))
    }
}

#Preview("OnboardingScaffold — language step + back") {
    OnboardingScaffold(
        progress: 0.33,
        subtitle: "So we understand each other better.",
        headline: "Choose your app language",
        primaryTitle: "Continue",
        isPrimaryEnabled: true,
        showsBack: true,
        onPrimary: {},
        onBack: {}
    ) {
        Text("Language rows go here")
            .foregroundColor(DSColor.Text.heading)
    }
}
