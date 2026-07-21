/// `creatingCard` step (new-customer branch) — idempotent card creation, retry, and
/// the create-failure alert's dismiss target.
extension OnboardingViewModel {
    /// Entry action for `creatingCard` — invoked from `continueFromLoyaltyDecision()`
    /// and, unchanged, on bootstrap resume (the operation is idempotent, so silently
    /// re-running it on relaunch is safe).
    func performCreateCard() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        analytics.trackCreateCardAttempted(file: #fileID)
        Task {
            do {
                let card = try await loyaltyCardRepository.createCard(userId: userId)
                analytics.trackCreateCardSucceeded(file: #fileID)
                complete(with: card)
            } catch {
                isLoading = false
                analytics.trackCreateCardFailed(reason: Self.analyticsReason(for: error), file: #fileID)
                activeAlert = .createCardFailed
            }
        }
    }

    public func retryCreateCard() {
        guard !isLoading else { return }
        activeAlert = nil
        analytics.trackRetryTapped(step: OnboardingStep.creatingCard.rawValue, file: #fileID)
        performCreateCard()
    }

    public func dismissCreateCardFailure() {
        activeAlert = nil
        selectedBranch = nil
        advance(via: .createCardFailureDismissed)
    }
}
