import SwiftUI
import DesignSystem
import DataProfile
import DataLoyaltyCard
import CoreExtensions

/// Root onboarding content — owns the view model via `@State` (same pattern as
/// `LoginFlowContainer`), applies the selected locale, runs bootstrap once, and
/// switches content by `viewModel.step`. Name + language screens are Task 4.2;
/// loyalty-decision and create-card screens are Task 4.3; the scanner branch
/// (`scannerPermission`/`scanning`/`manualCardEntry`) is Task 4.4;
/// `ProcessingScanScreen` (`.processingScan`) is Task 4.5.
struct OnboardingFlowScreen: View {
    @State private var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking

    init(
        userId: String,
        profileRepository: ProfileRepository,
        loyaltyCardRepository: LoyaltyCardRepository,
        progressStore: any OnboardingProgressStoring,
        appLanguagePreference: any AppLanguagePreferenceStoring,
        analytics: OnboardingAnalyticsTracking,
        onCompleted: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: OnboardingViewModel(
                userId: userId,
                profileRepository: profileRepository,
                loyaltyCardRepository: loyaltyCardRepository,
                progressStore: progressStore,
                appLanguagePreference: appLanguagePreference,
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
                        OnboardingProgressBar(progress: viewModel.progressFraction)
                            .padding(.top, DSConstant.medium.value)
                            .padding(.horizontal, DSConstant.large.value)
                            // Keep the bar above sliding step content so a full-bleed
                            // child background can never paint over it.
                            .zIndex(1)
                    }

                    stepContent
                        .transition(stepTransition)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LinearGradient.minitBackground.ignoresSafeArea())
                .animation(.easeInOut(duration: 0.32), value: viewModel.step)
                .animation(.easeInOut(duration: 0.32), value: viewModel.progressFraction)
            }
        }
        .environment(\.locale, currentLocale)
        .task {
            await viewModel.bootstrap()
        }
        .alert(
            OnboardingLocalizedString.string("onboarding.alert.createFailed.title", locale: currentLocale),
            isPresented: bootstrapAlertPresented
        ) {
            Button(OnboardingLocalizedString.string("onboarding.alert.action.retry", locale: currentLocale)) {
                viewModel.retryBootstrap()
            }
        } message: {
            Text(OnboardingLocalizedString.string("onboarding.alert.bootstrapFailed.message", locale: currentLocale))
        }
    }

    private var currentLocale: Locale {
        Locale(identifier: viewModel.selectedLanguage.rawValue)
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
        case .processingScan:
            ProcessingScanScreen(viewModel: viewModel, analytics: analytics)
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
        appLanguagePreference: PreviewAppLanguagePreferenceStore(),
        analytics: PreviewOnboardingAnalyticsTracking(),
        onCompleted: {}
    )
}
