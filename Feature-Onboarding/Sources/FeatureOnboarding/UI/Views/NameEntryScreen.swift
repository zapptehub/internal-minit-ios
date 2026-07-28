import SwiftUI
import DesignSystem

/// Name-entry step — borderless oversized field (same pattern as `EmailEntryScreen`).
struct NameEntryScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking
    @Environment(\.locale) private var locale
    @FocusState private var isNameFieldFocused: Bool

    /// Figma default size (30pt); `@ScaledMetric` keeps oversized-field look while
    /// respecting Dynamic Type (Task 6.2).
    @ScaledMetric(relativeTo: .title) private var nameFieldFontSize: CGFloat = 30
    /// Extra space below the headline so the field sits mid-screen (Figma).
    private let nameFieldTopPadding: CGFloat = 88

    var body: some View {
        OnboardingScaffold(
            subtitle: OnboardingLocalizedString.string("onboarding.name.subtitle", locale: locale),
            headline: OnboardingLocalizedString.string("onboarding.name.headline", locale: locale),
            primaryTitle: OnboardingLocalizedString.string("onboarding.button.continue", locale: locale),
            isPrimaryEnabled: viewModel.canContinueFromName && !viewModel.isLoading,
            isPrimaryLoading: viewModel.isLoading,
            showsBack: false,
            onPrimary: {
                viewModel.continueFromName()
            }
        ) {
            VStack(alignment: .leading, spacing: DSConstant.medium.value) {
                TextField(
                    OnboardingLocalizedString.string("onboarding.name.placeholder", locale: locale),
                    text: $viewModel.name
                )
                .font(.system(size: nameFieldFontSize))
                .foregroundColor(DSColor.Text.heading)
                .tint(DSColor.Text.heading)
                .textContentType(.givenName)
                .autocapitalization(.words)
                .focused($isNameFieldFocused)
                .submitLabel(.continue)
                .onSubmit {
                    guard viewModel.canContinueFromName else { return }
                    viewModel.continueFromName()
                }

                if let errorMessage = viewModel.errorMessage {
                    DSWarningMessage(message: errorMessage)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, nameFieldTopPadding)
        }
        .onAppear {
            analytics.trackNameScreenViewed(file: #fileID)
            isNameFieldFocused = true
        }
    }
}

#Preview("NameEntryScreen — empty") {
    NameEntryScreen(
        viewModel: PreviewOnboarding.makeViewModel(),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}

#Preview("NameEntryScreen — filled") {
    NameEntryScreen(
        viewModel: PreviewOnboarding.makeViewModel(name: "Iveta"),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}

#Preview("NameEntryScreen — Dynamic Type xxxLarge", traits: .sizeThatFitsLayout) {
    NameEntryScreen(
        viewModel: PreviewOnboarding.makeViewModel(name: "Iveta"),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
    .dynamicTypeSize(.xxxLarge)
}

#Preview("NameEntryScreen — locale sk") {
    NameEntryScreen(
        viewModel: PreviewOnboarding.makeViewModel(preferredLanguages: ["sk-SK"]),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
    .environment(\.locale, Locale(identifier: "sk"))
}

#Preview("NameEntryScreen — compact width") {
    NameEntryScreen(
        viewModel: PreviewOnboarding.makeViewModel(),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
    .frame(width: 320)
}
