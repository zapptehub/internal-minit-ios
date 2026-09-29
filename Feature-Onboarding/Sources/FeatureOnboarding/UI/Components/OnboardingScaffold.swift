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
                    .typography(.bodyMediumSmall)
                    .foregroundColor(OnboardingScaffoldHeader.color)

                headlineText
            }
            .padding(.top, DSConstant.mediumLarge.value)
            .background(OnboardingFrameReader(id: OnboardingFrameID.header))

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
            .background(OnboardingFrameReader(id: OnboardingFrameID.bottomBar))
            .padding(.bottom, DSConstant.medium.value)
        }
        .padding(.horizontal, DSConstant.large.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Do *not* `.ignoresSafeArea()` here — `OnboardingFlowScreen` already paints the
        // same gradient full-bleed behind the persistent progress bar. Expanding this
        // background past the scaffold's bounds covers that bar (especially when the
        // screen wraps the scaffold in a `GeometryReader`, as create/claim finish do).
        .background(LinearGradient.minitBackground)
    }

    @ViewBuilder
    private var headlineText: some View {
        let text = Text(headline)
            .typography(.headingLargeSemibold)
            .foregroundColor(DSColor.Text.inverse)

        if let headlineLineLimit {
            text.lineLimit(headlineLineLimit, reservesSpace: true)
        } else {
            text.fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Figma binds this text to `text/headings` `#1A1A1A`.
/// DS `Text.heading` is `#331A00`, so the subtitle uses `Text.primary`, which has the same hex.
enum OnboardingScaffoldHeader {
    static let color = DSColor.Text.primary
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
    .background(LinearGradient.minitBackground.ignoresSafeArea())
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
    .background(LinearGradient.minitBackground.ignoresSafeArea())
}
