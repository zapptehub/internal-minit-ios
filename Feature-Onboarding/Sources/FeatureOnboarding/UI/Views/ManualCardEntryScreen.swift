import SwiftUI
import DesignSystem

/// Fallback text-entry screen offered from the camera-permission-denied alert (and
/// directly from `scannerPermission`/`scanning` on unsupported hardware). No designer
/// reference exists for this screen (Task 1.1 follow-up #2) — built as a provisional,
/// DS-consistent screen using the standard bordered `DSInputField` rather than the
/// borderless pattern `NameEntryScreen` uses, since that borderless look has an
/// established precedent elsewhere in the app and this screen doesn't (per the Task
/// 2.1 mapping decision).
struct ManualCardEntryScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking
    @State private var code: String = ""

    var body: some View {
        OnboardingScaffold(
            subtitle: String(localized: "onboarding.manualEntry.subtitle", bundle: .module),
            headline: String(localized: "onboarding.manualEntry.headline", bundle: .module),
            primaryTitle: String(localized: "onboarding.button.continue", bundle: .module),
            isPrimaryEnabled: canContinue,
            isPrimaryLoading: viewModel.isLoading,
            showsBack: true,
            onPrimary: {
                viewModel.submitManualCardCode(code)
            },
            onBack: {
                viewModel.goBack()
            }
        ) {
            VStack(alignment: .leading, spacing: DSConstant.medium.value) {
                DSInputField(
                    label: String(localized: "onboarding.manualEntry.placeholder", bundle: .module),
                    text: $code,
                    placeholder: String(localized: "onboarding.manualEntry.placeholder", bundle: .module)
                )
                .textInputAutocapitalization(.characters)
                .submitLabel(.continue)
                .onSubmit {
                    guard canContinue else { return }
                    viewModel.submitManualCardCode(code)
                }

                if let errorMessage = viewModel.errorMessage {
                    DSWarningMessage(message: errorMessage)
                }
            }
        }
        .onAppear {
            analytics.trackManualCardEntryScreenViewed(file: #fileID)
        }
    }

    private var canContinue: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }
}

#Preview("ManualCardEntryScreen") {
    ManualCardEntryScreen(
        viewModel: PreviewOnboarding.makeViewModel(),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}
