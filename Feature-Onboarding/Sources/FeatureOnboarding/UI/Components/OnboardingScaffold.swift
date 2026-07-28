import SwiftUI
import DesignSystem

/// Full-bleed orange→cream gradient shell shared by every non-camera onboarding screen:
/// subtitle + headline, content slot, and bottom CTA bar.
///
/// The top progress bar is *not* rendered here — `OnboardingFlowScreen` renders a
/// single persistent `OnboardingProgressBar` above this scaffold instead, so it can
/// smoothly animate its fill and stay put while the scaffold itself slides in/out
/// during step transitions (see that file's doc comment).
///
/// Subtitle is dark and headline is white on every gradient step (matches Figma).
struct OnboardingScaffold<Content: View>: View {
    let subtitle: String
    let headline: String
    let primaryTitle: String
    let isPrimaryEnabled: Bool
    var isPrimaryLoading: Bool = false
    var showsBack: Bool = false
    /// When set, reserves this many lines' worth of vertical space for `headline`
    /// regardless of how many lines the translated text actually wraps to. Without this,
    /// a headline that wraps to a different line count per locale (e.g. English's 2-line
    /// "Choose your app language" vs. Slovak's 1-line "Vyber jazyk aplikácie") changes how
    /// much vertical space the header takes, which shifts the position of any content below
    /// it that's laid out relative to the remaining space (like `LanguageSelectionScreen`'s
    /// row list). `nil` (the default) preserves the previous "size to fit" behavior for
    /// screens that don't need this.
    var headlineLineLimit: Int? = nil
    let onPrimary: () -> Void
    var onBack: (() -> Void)? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text(subtitle)
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.heading)

                headlineText
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
        // Do *not* `.ignoresSafeArea()` here — `OnboardingFlowScreen` already paints the
        // same gradient full-bleed behind the persistent progress bar. Expanding this
        // background past the scaffold's bounds covers that bar (especially when the
        // screen wraps the scaffold in a `GeometryReader`, as create/claim finish do).
        .background(LinearGradient.onboardingBackground)
    }

    @ViewBuilder
    private var headlineText: some View {
        let text = Text(headline)
            .typography(.headingLargeSemibold)
            .foregroundColor(DSColor.Text.inverse)
            .tracking(-1)

        if let headlineLineLimit {
            text.lineLimit(headlineLineLimit, reservesSpace: true)
        } else {
            text.fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension LinearGradient {
    /// Full-bleed orange→cream onboarding background. Shared with
    /// `OnboardingFlowScreen`, which paints it behind the persistent progress bar too
    /// (that bar now lives outside this scaffold — see this file's doc comment) —
    /// keeping it here as the single definition avoids the two drifting apart.
    static var onboardingBackground: LinearGradient {
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
    .background(LinearGradient.onboardingBackground.ignoresSafeArea())
}

#Preview("OnboardingScaffold — language step + back") {
    OnboardingScaffold(
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
    .background(LinearGradient.onboardingBackground.ignoresSafeArea())
}
