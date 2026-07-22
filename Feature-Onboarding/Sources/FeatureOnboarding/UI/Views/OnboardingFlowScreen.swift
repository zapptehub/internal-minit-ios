import SwiftUI
import DesignSystem
import DataProfile
import DataLoyaltyCard

/// Root onboarding content — owns the view model via `@State` (same pattern as
/// `LoginFlowContainer`), applies the selected locale, runs bootstrap once, and
/// switches content by `viewModel.step`. Name + language screens are Task 4.2;
/// later steps render a temporary stub until Tasks 4.3–4.5 land.
struct OnboardingFlowScreen: View {
    @State private var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking

    init(
        userId: String,
        profileRepository: ProfileRepository,
        loyaltyCardRepository: LoyaltyCardRepository,
        progressStore: any OnboardingProgressStoring,
        analytics: OnboardingAnalyticsTracking,
        onCompleted: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: OnboardingViewModel(
                userId: userId,
                profileRepository: profileRepository,
                loyaltyCardRepository: loyaltyCardRepository,
                progressStore: progressStore,
                analytics: analytics,
                onCompleted: onCompleted
            )
        )
        self.analytics = analytics
    }

    var body: some View {
        Group {
            if viewModel.isBootstrapping {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DSColor.Background.Layer.level0.ignoresSafeArea())
            } else {
                stepContent
            }
        }
        .environment(\.locale, Locale(identifier: viewModel.selectedLanguage.rawValue))
        .task {
            await viewModel.bootstrap()
        }
        .alert(
            String(localized: "onboarding.alert.createFailed.title", bundle: .module),
            isPresented: bootstrapAlertPresented
        ) {
            Button(String(localized: "onboarding.alert.action.retry", bundle: .module)) {
                viewModel.retryBootstrap()
            }
        } message: {
            Text(String(localized: "onboarding.alert.bootstrapFailed.message", bundle: .module))
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .name:
            NameEntryScreen(viewModel: viewModel, analytics: analytics)
        case .language:
            LanguageSelectionScreen(viewModel: viewModel, analytics: analytics)
        default:
            OnboardingUpcomingStepStub(viewModel: viewModel)
        }
    }

    private var bootstrapAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.activeAlert == .bootstrapFetchFailed },
            set: { _ in
                // Keep showing until Retry — dismissing without retry would leave the
                // user unable to proceed safely.
            }
        )
    }
}

#Preview("OnboardingFlowScreen") {
    OnboardingFlowScreen(
        userId: "preview",
        profileRepository: PreviewProfileRepository(),
        loyaltyCardRepository: PreviewLoyaltyCardRepository(),
        progressStore: PreviewOnboardingProgressStore(),
        analytics: PreviewOnboardingAnalyticsTracking(),
        onCompleted: {}
    )
}

/// Temporary stand-in for steps that land in Tasks 4.3–4.5 so Continue from language
/// doesn't dead-end during development.
private struct OnboardingUpcomingStepStub: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
            progress: viewModel.step.progressFraction,
            subtitle: String(localized: "onboarding.loyalty.subtitle", bundle: .module),
            headline: String(localized: "onboarding.placeholder.headline", bundle: .module),
            primaryTitle: String(localized: "onboarding.button.continue", bundle: .module),
            isPrimaryEnabled: false,
            showsBack: viewModel.canGoBack,
            onPrimary: {},
            onBack: { viewModel.goBack() }
        ) {
            Text(String(localized: "onboarding.placeholder.subtitle", bundle: .module))
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.inverse.opacity(0.85))
        }
    }
}
