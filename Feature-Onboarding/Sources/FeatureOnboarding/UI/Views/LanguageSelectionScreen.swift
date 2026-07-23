import SwiftUI
import DesignSystem

/// Language-selection step — Slovak / Hungarian / English rows via `DSSelectableRowGroup`.
/// Locale switches immediately on row tap through `viewModel.selectLanguage`; Continue
/// persists the durable choice.
struct LanguageSelectionScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking

    var body: some View {
        OnboardingScaffold(
            subtitle: String(localized: "onboarding.language.subtitle", bundle: .module),
            headline: String(localized: "onboarding.language.headline", bundle: .module),
            primaryTitle: String(localized: "onboarding.button.continue", bundle: .module),
            isPrimaryEnabled: viewModel.canContinueFromLanguage,
            showsBack: true,
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
                                label: String(localized: "onboarding.language.slovak", bundle: .module)
                            ),
                            .init(
                                value: .hu,
                                label: String(localized: "onboarding.language.hungarian", bundle: .module)
                            ),
                            .init(
                                value: .en,
                                label: String(localized: "onboarding.language.english", bundle: .module)
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
