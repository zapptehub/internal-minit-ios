import SwiftUI
import DesignSystem

/// Language-selection step — Slovak / Hungarian / English rows via `DSSelectableRowGroup`.
/// Locale switches immediately on row tap through `viewModel.selectLanguage`; Continue
/// persists the durable choice.
struct LanguageSelectionScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking
    @Environment(\.locale) private var locale

    var body: some View {
        OnboardingScaffold(
            subtitle: OnboardingLocalizedString.string("onboarding.language.subtitle", locale: locale),
            headline: OnboardingLocalizedString.string("onboarding.language.headline", locale: locale),
            primaryTitle: OnboardingLocalizedString.string("onboarding.button.continue", locale: locale),
            isPrimaryEnabled: viewModel.canContinueFromLanguage,
            showsBack: true,
            // The row list's position below is computed as a fraction of the remaining
            // space (see the GeometryReader below), so without a fixed headline height the
            // list shifts depending on whether the translated headline wraps to 1 or 2
            // lines (e.g. Slovak's 1-line vs. English's 2-line copy).
            headlineLineLimit: 2,
            onPrimary: {
                viewModel.continueFromLanguage()
            },
            onBack: {
                viewModel.goBack()
            }
        ) {
            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 0) {
                    // First row starts around the vertical middle of the content area (Figma).
                    Color.clear
                        .frame(height: proxy.size.height * 0.35)

                    DSSelectableRowGroup(
                        options: [
                            .init(
                                value: OnboardingLanguageCode.sk,
                                label: OnboardingLocalizedString.string("onboarding.language.slovak", locale: locale)
                            ),
                            .init(
                                value: .hu,
                                label: OnboardingLocalizedString.string("onboarding.language.hungarian", locale: locale)
                            ),
                            .init(
                                value: .en,
                                label: OnboardingLocalizedString.string("onboarding.language.english", locale: locale)
                            )
                        ],
                        selection: languageBinding
                    )

                    Spacer(minLength: 0)
                }
            }
        }
        .onAppear {
            analytics.trackLanguageScreenViewed(file: #fileID)
        }
    }

    private var languageBinding: Binding<OnboardingLanguageCode> {
        Binding(
            get: { viewModel.selectedLanguage },
            set: { viewModel.selectLanguage($0) }
        )
    }
}

#Preview("LanguageSelectionScreen — English") {
    LanguageSelectionScreen(
        viewModel: PreviewOnboarding.makeViewModel(preferredLanguages: ["en-US"]),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}

#Preview("LanguageSelectionScreen — Slovak") {
    LanguageSelectionScreen(
        viewModel: PreviewOnboarding.makeViewModel(preferredLanguages: ["sk-SK"]),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}

#Preview("LanguageSelectionScreen — Hungarian locale") {
    LanguageSelectionScreen(
        viewModel: PreviewOnboarding.makeViewModel(preferredLanguages: ["hu-HU"]),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
    .environment(\.locale, Locale(identifier: "hu"))
}

#Preview("LanguageSelectionScreen — Dynamic Type accessibility3") {
    LanguageSelectionScreen(
        viewModel: PreviewOnboarding.makeViewModel(preferredLanguages: ["en-US"]),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
    .dynamicTypeSize(.accessibility3)
}
