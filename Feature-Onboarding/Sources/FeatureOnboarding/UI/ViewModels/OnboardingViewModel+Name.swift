import Foundation

/// `name` step — collect and persist the display name. No routing decisions here
/// beyond "done, move on"; see `OnboardingRouter` for where `.language` comes from.
extension OnboardingViewModel {
    public var canContinueFromName: Bool {
        !name.onboardingTrimmed.isEmpty
    }

    public func continueFromName() {
        guard !isLoading else { return }
        let trimmed = name.onboardingTrimmed
        guard !trimmed.isEmpty else {
            analytics.trackNameValidationFailed(file: #fileID)
            return
        }

        name = trimmed
        errorMessage = nil
        isLoading = true
        Task {
            do {
                try await profileRepository.updateName(userId: userId, name: trimmed)
                isLoading = false
                advance(via: .nameConfirmed)
            } catch {
                isLoading = false
                errorMessage = OnboardingLocalizedString.string(
                    "onboarding.error.profileSaveFailed",
                    locale: Locale(identifier: selectedLanguage.rawValue)
                )
            }
        }
    }
}
