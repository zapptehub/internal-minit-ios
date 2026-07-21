/// `loyaltyDecision` step — branch choice only. Kicking off the new-customer create
/// flow is delegated to the CreateCard section (`performCreateCard()`); the
/// existing-card branch just hands off to the Scanner section by moving to
/// `scannerPermission` — see `OnboardingRouter` for both destinations.
extension OnboardingViewModel {
    public var canContinueFromLoyaltyDecision: Bool { selectedBranch != nil }

    public func selectBranch(_ branch: OnboardingLoyaltyBranch) {
        guard selectedBranch != branch else { return }
        selectedBranch = branch
        analytics.trackLoyaltyBranchSelected(branch: branch.rawValue, file: #fileID)
    }

    public func continueFromLoyaltyDecision() {
        guard !isLoading, let branch = selectedBranch else { return }
        guard advance(via: .loyaltyDecisionConfirmed(branch)) else { return }

        if branch == .newCustomer {
            performCreateCard()
        }
    }
}
