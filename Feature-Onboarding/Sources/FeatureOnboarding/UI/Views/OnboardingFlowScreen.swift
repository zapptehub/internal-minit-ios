import SwiftUI
import DesignSystem
import DataProfile
import DataLoyaltyCard

/// Root onboarding content — owns the view model via `@State` (same pattern as
/// `LoginFlowContainer`), applies the selected locale, runs bootstrap once, and
/// switches content by `viewModel.step`. Name + language screens are Task 4.2;
/// loyalty-decision and create-card screens are Task 4.3; the scanner branch
/// (`scannerPermission`/`scanning`/`manualCardEntry`) is Task 4.4. `scanReview` still
/// renders a temporary stub until Task 4.5 lands.
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
                // The progress bar lives here — outside the per-step `stepContent`
                // switch — as a single persistent view so it can smoothly animate its
                // fill width in place. `stepContent` itself is the thing that slides
                // (push/pop, mirroring `NavigationStack`) when `viewModel.step`
                // changes; `OnboardingScaffold` no longer renders its own copy.
                VStack(alignment: .leading, spacing: 0) {
                    // Hidden specifically for the full-screen camera step (Task 1.1:
                    // "No progress bar visible on the camera screen") — every other
                    // step keeps it, including the brief `scannerPermission` check.
                    if viewModel.step != .scanning {
                        OnboardingProgressBar(progress: viewModel.step.progressFraction)
                            .padding(.top, DSConstant.medium.value)
                            .padding(.horizontal, DSConstant.large.value)
                    }

                    stepContent
                        .transition(stepTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LinearGradient.onboardingBackground.ignoresSafeArea())
                .animation(.easeInOut(duration: 0.32), value: viewModel.step)
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
        case .loyaltyDecision:
            LoyaltyDecisionScreen(viewModel: viewModel, analytics: analytics)
        case .creatingCard:
            CreateCardScreen(viewModel: viewModel, analytics: analytics)
        case .scannerPermission:
            ScannerPermissionScreen(viewModel: viewModel, analytics: analytics)
        case .scanning:
            ScanningScreen(viewModel: viewModel, analytics: analytics)
        case .manualCardEntry:
            ManualCardEntryScreen(viewModel: viewModel, analytics: analytics)
        case .scanReview:
            OnboardingUpcomingStepStub(viewModel: viewModel)
        }
    }

    /// Push (forward) slides the new step in from the trailing edge while the old one
    /// exits leading, like `NavigationStack.push`; back mirrors it in reverse, like
    /// `.pop`. Recomputed from `viewModel.stepDirection` on every step change.
    private var stepTransition: AnyTransition {
        switch viewModel.stepDirection {
        case .forward:
            return .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
        case .backward:
            return .asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .trailing))
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

/// Temporary stand-in for `scanReview`, which lands in Task 4.5, so a recognized/
/// manually-submitted code doesn't dead-end during development.
private struct OnboardingUpcomingStepStub: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        OnboardingScaffold(
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
