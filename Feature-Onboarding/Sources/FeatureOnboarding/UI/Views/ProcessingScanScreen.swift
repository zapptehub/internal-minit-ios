import SwiftUI
import DesignSystem

/// `processingScan` step (existing-card branch) — same finishing-up chrome as
/// `CreateCardScreen`, but driven by an in-flight (or just-completed) `claimCard`
/// rather than `createCard`. No back affordance. Terminal CTA is unified to
/// "Enter Minit" in both the loading (disabled) and success (enabled) states.
///
/// Claim failure surfaces as a basic system alert rather than a status-card
/// variant, per the Task 1.1/1.2 decision. Two shapes:
/// - `.alreadyClaimedByOtherUser` — dismiss-only → back to `scanning` /
///   `manualCardEntry` depending on claim source
/// - `.generic` — Retry (re-invokes the same idempotent claim) or Dismiss →
///   `loyaltyDecision`
struct ProcessingScanScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking
    @Environment(\.locale) private var locale

    var body: some View {
        // Create Card centres its card in the scaffold slot (Figma). This step
        // still centres on the step: the shared `DSStatusCard` chrome matches,
        // the overlay position does not.
        GeometryReader { screen in
            OnboardingScaffold(
                subtitle: OnboardingLocalizedString.string("onboarding.finish.subtitle", locale: locale),
                headline: OnboardingLocalizedString.string("onboarding.finish.headline", locale: locale),
                primaryTitle: OnboardingLocalizedString.string("onboarding.button.enterMinit", locale: locale),
                isPrimaryEnabled: viewModel.linkedCard != nil,
                showsBack: false,
                onPrimary: {
                    viewModel.tapEnterMinit()
                }
            ) {
                Color.clear
            }
            .overlay {
                statusCard
                    .padding(.horizontal, DSConstant.large.value)
                    .position(x: screen.size.width / 2, y: screen.size.height / 2)
            }
        }
        .onAppear {
            analytics.trackProcessingScanScreenViewed(file: #fileID)
        }
        .alert(
            claimFailedAlertTitle,
            isPresented: claimFailedAlertPresented
        ) {
            if case .claimCardFailed(let kind) = viewModel.activeAlert, kind == .generic {
                Button(OnboardingLocalizedString.string("onboarding.alert.action.retry", locale: locale)) {
                    viewModel.retryClaimCard()
                }
            }
            Button(
                OnboardingLocalizedString.string("onboarding.alert.action.dismiss", locale: locale),
                role: .cancel
            ) {
                viewModel.dismissClaimFailure()
            }
        } message: {
            Text(claimFailedAlertMessage)
        }
    }

    @ViewBuilder
    private var statusCard: some View {
        if viewModel.linkedCard != nil {
            DSStatusCard(state: .success(
                title: OnboardingLocalizedString.string("onboarding.finish.success.title", locale: locale)
            ))
        } else {
            DSStatusCard(state: .loading(
                title: OnboardingLocalizedString.string("onboarding.finish.processing.title", locale: locale),
                subtitle: OnboardingLocalizedString.string("onboarding.finish.processing.subtitle", locale: locale)
            ))
        }
    }

    private var claimFailedAlertPresented: Binding<Bool> {
        Binding(
            get: {
                if case .claimCardFailed = viewModel.activeAlert { return true }
                return false
            },
            set: { _ in
                // Dismissed only via the explicit Retry/Dismiss buttons above, which
                // already clear `activeAlert` themselves.
            }
        )
    }

    private var claimFailedAlertTitle: String {
        switch viewModel.activeAlert {
        case .claimCardFailed(.alreadyClaimedByOtherUser):
            return OnboardingLocalizedString.string("onboarding.alert.alreadyClaimed.title", locale: locale)
        default:
            return OnboardingLocalizedString.string("onboarding.alert.claimFailed.title", locale: locale)
        }
    }

    private var claimFailedAlertMessage: String {
        switch viewModel.activeAlert {
        case .claimCardFailed(.alreadyClaimedByOtherUser):
            return OnboardingLocalizedString.string("onboarding.alert.alreadyClaimed.message", locale: locale)
        default:
            return OnboardingLocalizedString.string("onboarding.alert.claimFailed.message", locale: locale)
        }
    }
}

#Preview("ProcessingScanScreen — loading") {
    VStack(spacing: 0) {
        OnboardingProgressBar(progress: OnboardingStep.processingScan.progressFraction())
            .padding(.top, DSConstant.medium.value)
            .padding(.horizontal, DSConstant.large.value)
        ProcessingScanScreen(
            viewModel: PreviewOnboarding.makeViewModel(),
            analytics: PreviewOnboardingAnalyticsTracking()
        )
    }
    .background(LinearGradient.minitBackground.ignoresSafeArea())
}

#Preview("ProcessingScanScreen — success") {
    // Drive the real claim path so `linkedCard` is set the same way production
    // does — `PreviewLoyaltyCardRepository.claimCard` resolves immediately, so
    // the canvas settles on success almost instantly. Advances are routed
    // through `OnboardingRouter` (same source-step guards as production).
    let viewModel = PreviewOnboarding.makeViewModel()
    _ = viewModel.advance(via: .nameConfirmed)
    _ = viewModel.advance(via: .languageConfirmed)
    _ = viewModel.advance(via: .loyaltyDecisionConfirmed(.existingCard))
    viewModel.cameraPermissionGranted()
    viewModel.didScanCode("MINIT-SEED-0001")
    return VStack(spacing: 0) {
        OnboardingProgressBar(progress: OnboardingStep.processingScan.progressFraction(isFinishComplete: true))
            .padding(.top, DSConstant.medium.value)
            .padding(.horizontal, DSConstant.large.value)
        ProcessingScanScreen(
            viewModel: viewModel,
            analytics: PreviewOnboardingAnalyticsTracking()
        )
    }
    .background(LinearGradient.minitBackground.ignoresSafeArea())
}

#Preview("ProcessingScanScreen — already-claimed alert") {
    let viewModel = PreviewOnboarding.makeViewModel()
    _ = viewModel.advance(via: .nameConfirmed)
    _ = viewModel.advance(via: .languageConfirmed)
    _ = viewModel.advance(via: .loyaltyDecisionConfirmed(.existingCard))
    _ = viewModel.advance(via: .cameraPermissionGranted)
    _ = viewModel.advance(via: .codeSubmittedForClaim)
    // Force the alert presentation without waiting on a real failing claim —
    // production reaches this via `performClaim`'s catch path.
    viewModel.activeAlert = .claimCardFailed(kind: .alreadyClaimedByOtherUser)
    return VStack(spacing: 0) {
        OnboardingProgressBar(progress: OnboardingStep.processingScan.progressFraction())
            .padding(.top, DSConstant.medium.value)
            .padding(.horizontal, DSConstant.large.value)
        ProcessingScanScreen(
            viewModel: viewModel,
            analytics: PreviewOnboardingAnalyticsTracking()
        )
    }
    .background(LinearGradient.minitBackground.ignoresSafeArea())
}
