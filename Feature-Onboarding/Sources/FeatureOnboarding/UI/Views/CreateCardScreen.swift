import SwiftUI
import DesignSystem

/// `creatingCard` step (new-customer branch) — shared "finishing up" chrome: a
/// `DSStatusCard` that shows loading until `createCard()` resolves, then success. No
/// back affordance (matrix: can't step back once a create is in flight or done). The
/// terminal button is "Continue" in both the loading (disabled) and success (enabled)
/// states, matching Figma. Processing scan still shows Enter Minit.
///
/// Figma centres the card in the band between the headline block and the button,
/// with 32pt gaps at both ends of that band and an extra 56pt bottom inset. Those
/// 32pt gaps cancel, so the centre is `(headlineBottom + buttonTop - 56) / 2`.
/// The scaffold content slot already starts 24pt (`DSConstant.large`) below the
/// headline and ends at the button, so the card sits
/// `CreateCardStatusMetrics.contentCenterLift` above the slot's own centre.
///
/// Card-creation failure surfaces as a basic system alert (Retry / Dismiss) rather than
/// a bespoke status-card variant, per the Task 1.1/1.2 decision.
struct CreateCardScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking
    @Environment(\.locale) private var locale

    var body: some View {
        OnboardingScaffold(
            subtitle: OnboardingLocalizedString.string("onboarding.finish.subtitle", locale: locale),
            headline: OnboardingLocalizedString.string("onboarding.finish.headline", locale: locale),
            primaryTitle: OnboardingLocalizedString.string("onboarding.button.continue", locale: locale),
            isPrimaryEnabled: viewModel.linkedCard != nil,
            showsBack: false,
            onPrimary: {
                viewModel.tapEnterMinit()
            }
        ) {
            // The scaffold already insets 24pt on the sides, so the card fills the
            // content width (354pt on a 402pt frame).
            statusCard
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .offset(y: -CreateCardStatusMetrics.contentCenterLift)
        }
        .onAppear {
            analytics.trackCreatingCardScreenViewed(file: #fileID)
        }
        .alert(
            OnboardingLocalizedString.string("onboarding.alert.createFailed.title", locale: locale),
            isPresented: createFailedAlertPresented
        ) {
            Button(OnboardingLocalizedString.string("onboarding.alert.action.retry", locale: locale)) {
                viewModel.retryCreateCard()
            }
            Button(OnboardingLocalizedString.string("onboarding.alert.action.dismiss", locale: locale), role: .cancel) {
                viewModel.dismissCreateCardFailure()
            }
        } message: {
            Text(OnboardingLocalizedString.string("onboarding.alert.createFailed.message", locale: locale))
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        Group {
            if viewModel.linkedCard != nil {
                DSStatusCard(state: .success(
                    title: OnboardingLocalizedString.string("onboarding.finish.success.title", locale: locale)
                ))
            } else {
                DSStatusCard(state: .loading(
                    title: OnboardingLocalizedString.string("onboarding.finish.creating.title", locale: locale),
                    subtitle: OnboardingLocalizedString.string("onboarding.finish.processing.subtitle", locale: locale)
                ))
            }
        }
        .background(OnboardingFrameReader(id: OnboardingFrameID.statusCard))
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

/// Figma's extra 56pt bottom inset, expressed as a lift inside the scaffold slot.
enum CreateCardStatusMetrics {
    /// No spacing token is 56. `DSPrimitiveScale.step1400` is 56, but that step
    /// is a control height, not a spacing role.
    static let centeringBottomInset: CGFloat = 56

    /// `(DSConstant.large + centeringBottomInset) / 2`. See `CreateCardScreen`.
    static var contentCenterLift: CGFloat {
        (DSConstant.large.value + centeringBottomInset) / 2
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
