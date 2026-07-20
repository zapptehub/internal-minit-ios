import SwiftUI
import DesignSystem
import DataProfile
@_exported import DataLoyaltyCard

public enum FeatureOnboarding {
    /// Entry point for the post-auth onboarding flow. The real state machine and
    /// screens land in Tasks 4.1–4.5; this factory currently returns a placeholder
    /// so the app can wire the package (Task 5.2) and previews compile.
    @MainActor
    public static func createScreen(
        userId: String,
        profileRepository: ProfileRepository,
        loyaltyCardRepository: LoyaltyCardRepository,
        progressStore: any OnboardingProgressStoring,
        analytics: OnboardingAnalyticsTracking,
        onCompleted: @escaping () -> Void
    ) -> some View {
        OnboardingFlowContainer(
            userId: userId,
            profileRepository: profileRepository,
            loyaltyCardRepository: loyaltyCardRepository,
            progressStore: progressStore,
            analytics: analytics,
            onCompleted: onCompleted
        )
    }
}

/// Owns `@State` so the same dependencies survive body re-evaluations of the
/// presenting screen — same pattern as `LoginFlowContainer` in Feature-Login.
private struct OnboardingFlowContainer: View {
    let userId: String
    let profileRepository: ProfileRepository
    let loyaltyCardRepository: LoyaltyCardRepository
    let progressStore: any OnboardingProgressStoring
    let analytics: OnboardingAnalyticsTracking
    let onCompleted: () -> Void

    var body: some View {
        OnboardingPlaceholderScreen(
            userId: userId,
            analytics: analytics,
            onCompleted: onCompleted
        )
    }
}
