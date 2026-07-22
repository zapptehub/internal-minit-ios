import SwiftUI
import DesignSystem

/// `creatingCard` step (new-customer branch) — shared "finishing up" chrome: a centered
/// `DSStatusCard` that shows loading until `createCard()` resolves, then success. No
/// back affordance (matrix: can't step back once a create is in flight or done). The
/// terminal button is unified to "Enter Minit" in both the loading (disabled) and
/// success (enabled) states — the create-path mockup's "Continue" label is treated as
/// an inconsistency per the Task 1.1 checklist.
///
/// Card-creation failure surfaces as a basic system alert (Retry / Dismiss) rather than
/// a bespoke status-card variant, per the Task 1.1/1.2 decision.
struct CreateCardScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking

    var body: some View {
        OnboardingScaffold(
            progress: OnboardingStep.creatingCard.progressFraction,
            subtitle: String(localized: "onboarding.finish.subtitle", bundle: .module),
            headline: String(localized: "onboarding.finish.headline", bundle: .module),
            primaryTitle: String(localized: "onboarding.button.enterMinit", bundle: .module),
            isPrimaryEnabled: viewModel.linkedCard != nil,
            showsBack: false,
            onPrimary: {
                viewModel.tapEnterMinit()
            }
        ) {
            statusCard
                .frame(maxWidth: .infinity)
        }
        .onAppear {
            analytics.trackCreatingCardScreenViewed(file: #fileID)
        }
        .alert(
            String(localized: "onboarding.alert.createFailed.title", bundle: .module),
            isPresented: createFailedAlertPresented
        ) {
            Button(String(localized: "onboarding.alert.action.retry", bundle: .module)) {
                viewModel.retryCreateCard()
            }
            Button(String(localized: "onboarding.alert.action.dismiss", bundle: .module), role: .cancel) {
                viewModel.dismissCreateCardFailure()
            }
        } message: {
            Text(String(localized: "onboarding.alert.createFailed.message", bundle: .module))
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        if viewModel.linkedCard != nil {
            DSStatusCard(state: .success(
                title: String(localized: "onboarding.finish.success.title", bundle: .module)
            ))
        } else {
            DSStatusCard(state: .loading(
                title: String(localized: "onboarding.finish.creating.title", bundle: .module),
                subtitle: String(localized: "onboarding.finish.processing.subtitle", bundle: .module)
            ))
        }
    }

    private var createFailedAlertPresented: Binding<Bool> {
        Binding(
            get: { viewModel.activeAlert == .createCardFailed },
            set: { _ in
                // Dismissed only via the explicit Retry/Dismiss buttons above, which
                // already clear `activeAlert` themselves.
            }
        )
    }
}

#Preview("CreateCardScreen — loading") {
    CreateCardScreen(
        viewModel: PreviewOnboarding.makeViewModel(),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}

#Preview("CreateCardScreen — success") {
    // Drives the real flow so `linkedCard` gets set the same way production does —
    // `PreviewLoyaltyCardRepository.createCard` resolves immediately, so the canvas
    // settles on the success state almost instantly.
    let viewModel = PreviewOnboarding.makeViewModel()
    viewModel.selectBranch(.newCustomer)
    viewModel.continueFromLoyaltyDecision()
    return CreateCardScreen(
        viewModel: viewModel,
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}
