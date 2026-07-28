import SwiftUI
import DesignSystem
import DataProfile
@_exported import DataLoyaltyCard
@_exported import CoreExtensions

public enum FeatureOnboarding {
    /// Entry point for the post-auth onboarding flow. Owns a resumable
    /// `OnboardingViewModel` and renders name/language (Task 4.2); later steps
    /// stub until Tasks 4.3–4.5.
    @MainActor
    public static func createScreen(
        userId: String,
        profileRepository: ProfileRepository,
        loyaltyCardRepository: LoyaltyCardRepository,
        progressStore: any OnboardingProgressStoring,
        appLanguagePreference: any AppLanguagePreferenceStoring,
        analytics: OnboardingAnalyticsTracking,
        onCompleted: @escaping () -> Void
    ) -> some View {
        OnboardingFlowScreen(
            userId: userId,
            profileRepository: profileRepository,
            loyaltyCardRepository: loyaltyCardRepository,
            progressStore: progressStore,
            appLanguagePreference: appLanguagePreference,
            analytics: analytics,
            onCompleted: onCompleted
        )
    }
}
