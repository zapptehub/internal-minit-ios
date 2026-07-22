import SwiftUI
import DesignSystem

/// `loyaltyDecision` step — the loyalty-card preview plus the two mutually-exclusive
/// branch rows ("new customer" → `creatingCard`, "existing card" → the scanner branch,
/// Task 4.4). Continue is disabled until a row is tapped (no default choice, unlike
/// the language step).
struct LoyaltyDecisionScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    let analytics: OnboardingAnalyticsTracking

    var body: some View {
        OnboardingScaffold(
            progress: OnboardingStep.loyaltyDecision.progressFraction,
            subtitle: String(localized: "onboarding.loyalty.subtitle", bundle: .module),
            headline: String(localized: "onboarding.loyalty.headline", bundle: .module),
            primaryTitle: String(localized: "onboarding.button.continue", bundle: .module),
            isPrimaryEnabled: viewModel.canContinueFromLoyaltyDecision,
            showsBack: true,
            onPrimary: {
                viewModel.continueFromLoyaltyDecision()
            },
            onBack: {
                viewModel.goBack()
            }
        ) {
            VStack(alignment: .leading, spacing: DSConstant.large.value) {
                LoyaltyCardPreview()

                DSSelectableRowGroup(
                    options: [
                        .init(
                            value: OnboardingLoyaltyBranch.newCustomer,
                            label: String(localized: "onboarding.loyalty.option.newCustomer", bundle: .module)
                        ),
                        .init(
                            value: .existingCard,
                            label: String(localized: "onboarding.loyalty.option.existingCard", bundle: .module)
                        )
                    ],
                    selection: branchBinding
                )
            }
        }
        .onAppear {
            analytics.trackLoyaltyDecisionScreenViewed(file: #fileID)
        }
    }

    /// `Value` here is `OnboardingLoyaltyBranch?` — no row's `value` is ever `nil`, but
    /// the binding itself must be optional so neither row renders selected until the
    /// user taps one (there's no pre-selected default on this step, unlike language).
    private var branchBinding: Binding<OnboardingLoyaltyBranch?> {
        Binding(
            get: { viewModel.selectedBranch },
            set: { newValue in
                guard let newValue else { return }
                viewModel.selectBranch(newValue)
            }
        )
    }
}

#Preview("LoyaltyDecisionScreen — no selection") {
    LoyaltyDecisionScreen(
        viewModel: PreviewOnboarding.makeViewModel(),
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}

#Preview("LoyaltyDecisionScreen — new customer selected") {
    let viewModel = PreviewOnboarding.makeViewModel()
    viewModel.selectBranch(.newCustomer)
    return LoyaltyDecisionScreen(
        viewModel: viewModel,
        analytics: PreviewOnboardingAnalyticsTracking()
    )
}
