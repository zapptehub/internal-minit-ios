import Foundation
import DataProfile
import DataLoyaltyCard

/// Minimal no-op / in-memory conformances shared by every `#Preview` in this
/// module — `OnboardingTestUtilities` depends on `FeatureOnboarding`, so it
/// can't be used here without a cycle. Mirror of Feature-Login's `PreviewMocks`.
struct PreviewProfileRepository: ProfileRepository {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? {
        ProfileData(name: "Iveta", surname: "", email: "preview@example.com")
    }
}

@MainActor
final class PreviewOnboardingProgressStore: OnboardingProgressStoring {
    private var progressByUserId: [String: OnboardingProgress] = [:]

    func load(userId: String) throws -> OnboardingProgress? {
        progressByUserId[userId]
    }

    func save(_ progress: OnboardingProgress, userId: String) throws {
        progressByUserId[userId] = progress
    }

    func clear(userId: String) {
        progressByUserId[userId] = nil
    }
}

struct PreviewLoyaltyCardRepository: LoyaltyCardRepository {
    func createCard(userId: String) async throws -> LoyaltyCardData {
        LoyaltyCardData(code: "PREVIEW-NEW", ownerUserId: userId, points: 1410)
    }

    func claimCard(userId: String, code: String) async throws -> LoyaltyCardData {
        LoyaltyCardData(code: code, ownerUserId: userId, points: 1410)
    }

    func fetchLinkedCard(userId: String) async throws -> LoyaltyCardData? { nil }
}

struct PreviewOnboardingAnalyticsTracking: OnboardingAnalyticsTracking {
    func trackNameScreenViewed(file: String = #fileID) {}
    func trackLanguageScreenViewed(file: String = #fileID) {}
    func trackLoyaltyDecisionScreenViewed(file: String = #fileID) {}
    func trackCreatingCardScreenViewed(file: String = #fileID) {}
    func trackScannerScreenViewed(file: String = #fileID) {}
    func trackProcessingScanScreenViewed(file: String = #fileID) {}
    func trackManualCardEntryScreenViewed(file: String = #fileID) {}
    func trackNameValidationFailed(file: String = #fileID) {}
    func trackLanguageSelected(languageCode: String, file: String = #fileID) {}
    func trackLoyaltyBranchSelected(branch: String, file: String = #fileID) {}
    func trackCreateCardAttempted(file: String = #fileID) {}
    func trackCreateCardSucceeded(file: String = #fileID) {}
    func trackCreateCardFailed(reason: String, file: String = #fileID) {}
    func trackClaimCardAttempted(source: String, file: String = #fileID) {}
    func trackClaimCardSucceeded(source: String, file: String = #fileID) {}
    func trackClaimCardFailed(reason: String, source: String, file: String = #fileID) {}
    func trackCameraPermissionRequested(file: String = #fileID) {}
    func trackCameraPermissionGranted(file: String = #fileID) {}
    func trackCameraPermissionDenied(file: String = #fileID) {}
    func trackOpenSettingsTapped(file: String = #fileID) {}
    func trackManualEntryChosen(file: String = #fileID) {}
    func trackQRCodeScanned(file: String = #fileID) {}
    func trackRetryTapped(step: String, file: String = #fileID) {}
    func trackOnboardingResumed(step: String, file: String = #fileID) {}
    func trackOnboardingCompleted(file: String = #fileID) {}
    func trackEnterMinitTapped(file: String = #fileID) {}
}

@MainActor
enum PreviewOnboarding {
    static func makeViewModel(
        preferredLanguages: [String] = ["en-US"],
        name: String = ""
    ) -> OnboardingViewModel {
        let viewModel = OnboardingViewModel(
            userId: "preview",
            profileRepository: PreviewProfileRepository(),
            loyaltyCardRepository: PreviewLoyaltyCardRepository(),
            progressStore: PreviewOnboardingProgressStore(),
            analytics: PreviewOnboardingAnalyticsTracking(),
            preferredLanguages: preferredLanguages,
            onCompleted: {}
        )
        viewModel.name = name
        return viewModel
    }
}
