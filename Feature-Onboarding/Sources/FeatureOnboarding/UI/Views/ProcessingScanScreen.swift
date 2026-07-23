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

    var body: some View {
        // Same screen-center positioning as `CreateCardScreen` — the scaffold's
        // content slot isn't vertically centered on the full screen.
        GeometryReader { screen in
            OnboardingScaffold(
                subtitle: String(localized: "onboarding.finish.subtitle", bundle: .module),
                headline: String(localized: "onboarding.finish.headline", bundle: .module),
                primaryTitle: String(localized: "onboarding.button.enterMinit", bundle: .module),
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
                Button(String(localized: "onboarding.alert.action.retry", bundle: .module)) {
                    viewModel.retryClaimCard()
                }
            }
            Button(
                String(localized: "onboarding.alert.action.dismiss", bundle: .module),
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
                title: String(localized: "onboarding.finish.success.title", bundle: .module)
            ))
        } else {
            DSStatusCard(state: .loading(
                title: String(localized: "onboarding.finish.processing.title", bundle: .module),
                subtitle: String(localized: "onboarding.finish.processing.subtitle", bundle: .module)
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
            return String(localized: "onboarding.alert.alreadyClaimed.title", bundle: .module)
        default:
            return String(localized: "onboarding.alert.claimFailed.title", bundle: .module)
        }
    }

    private var claimFailedAlertMessage: String {
        switch viewModel.activeAlert {
        case .claimCardFailed(.alreadyClaimedByOtherUser):
            return String(localized: "onboarding.alert.alreadyClaimed.message", bundle: .module)
        default:
            return String(localized: "onboarding.alert.claimFailed.message", bundle: .module)
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
    .background(LinearGradient.onboardingBackground.ignoresSafeArea())
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
    .background(LinearGradient.onboardingBackground.ignoresSafeArea())
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
    .background(LinearGradient.onboardingBackground.ignoresSafeArea())
}
