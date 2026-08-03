import XCTest
@testable import FeatureOnboarding

final class OnboardingModelsTests: XCTestCase {
    // MARK: - PersistedOnboardingStep

    func testInitWithKnownRawValueResolvesToSupportedStep() {
        let persisted = PersistedOnboardingStep(rawValue: "language")

        XCTAssertEqual(persisted, .supported(.language))
        XCTAssertEqual(persisted.supportedStep, .language)
        XCTAssertEqual(persisted.rawValue, "language")
    }

    func testInitWithUnknownRawValueResolvesToUnsupportedAndPreservesRawValue() {
        // A newer app version could persist a step this (older) build has never heard of —
        // this must round-trip losslessly instead of silently mapping to some default step.
        let persisted = PersistedOnboardingStep(rawValue: "someFutureStep")

        XCTAssertEqual(persisted, .unsupported(rawValue: "someFutureStep"))
        XCTAssertNil(persisted.supportedStep)
        XCTAssertEqual(persisted.rawValue, "someFutureStep")
    }

    func testLegacyRenamedRawValueStillResolvesToProcessingScan() {
        // `processingScan`'s raw value is kept as "scanReview" so existing local checkpoints
        // written before the rename still resume correctly.
        let persisted = PersistedOnboardingStep(rawValue: "scanReview")

        XCTAssertEqual(persisted, .supported(.processingScan))
    }

    // MARK: - OnboardingAlert.id

    func testAlertIdIsStableAndUniquePerCase() {
        XCTAssertEqual(OnboardingAlert.createCardFailed.id, "createCardFailed")
        XCTAssertEqual(OnboardingAlert.cameraPermissionDenied.id, "cameraPermissionDenied")
        XCTAssertEqual(OnboardingAlert.bootstrapFetchFailed.id, "bootstrapFetchFailed")
    }

    func testClaimCardFailedIdIncludesFailureKindSoAlertsForBothKindsAreDistinct() {
        let alreadyClaimed = OnboardingAlert.claimCardFailed(kind: .alreadyClaimedByOtherUser)
        let generic = OnboardingAlert.claimCardFailed(kind: .generic)

        XCTAssertEqual(alreadyClaimed.id, "claimCardFailed.alreadyClaimedByOtherUser")
        XCTAssertEqual(generic.id, "claimCardFailed.generic")
        XCTAssertNotEqual(alreadyClaimed.id, generic.id)
    }

    // MARK: - OnboardingProgress

    func testConvenienceInitWrapsStepAsSupportedAndDefaultsToCurrentVersion() {
        let progress = OnboardingProgress(step: .name, language: .en)

        XCTAssertEqual(progress.step, .supported(.name))
        XCTAssertEqual(progress.language, .en)
        XCTAssertEqual(progress.version, OnboardingProgress.currentVersion)
    }

    func testConvenienceInitDefaultsLanguageToNil() {
        let progress = OnboardingProgress(step: .name)

        XCTAssertNil(progress.language)
    }

    func testPersistedStepInitPreservesUnsupportedStepAndExplicitVersion() {
        let progress = OnboardingProgress(
            persistedStep: .unsupported(rawValue: "futureStep"),
            language: .sk,
            version: OnboardingProgress.legacyVersion
        )

        XCTAssertEqual(progress.step, .unsupported(rawValue: "futureStep"))
        XCTAssertEqual(progress.language, .sk)
        XCTAssertEqual(progress.version, OnboardingProgress.legacyVersion)
    }

    func testLegacyAndCurrentVersionConstantsAreDistinct() {
        XCTAssertNotEqual(OnboardingProgress.legacyVersion, OnboardingProgress.currentVersion)
    }
}
