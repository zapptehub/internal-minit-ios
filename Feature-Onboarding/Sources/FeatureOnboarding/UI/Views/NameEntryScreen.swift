import SwiftUI
import DesignSystem

/// Name-entry step — borderless oversized field (same pattern as `EmailEntryScreen`).
struct NameEntryScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking
    @FocusState private var isNameFieldFocused: Bool

    private let nameFieldFontSize: CGFloat = 30
    /// Extra space below the headline so the field sits mid-screen (Figma).
    private let nameFieldTopPadding: CGFloat = 88

    var body: some View {
        OnboardingScaffold(
            subtitle: String(localized: "onboarding.name.subtitle", bundle: .module),
            headline: String(localized: "onboarding.name.headline", bundle: .module),
            primaryTitle: String(localized: "onboarding.button.continue", bundle: .module),
            isPrimaryEnabled: viewModel.canContinueFromName && !viewModel.isLoading,
            isPrimaryLoading: viewModel.isLoading,
            showsBack: false,
            onPrimary: {
                viewModel.continueFromName()
            }
        ) {
            VStack(alignment: .leading, spacing: DSConstant.medium.value) {
                TextField(
                    String(localized: "onboarding.name.placeholder", bundle: .module),
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
