import XCTest
@testable import FeatureOnboarding

final class OnboardingStepProgressTests: XCTestCase {
    func testEarlyStepsHaveIncreasingProgress() {
        XCTAssertEqual(OnboardingStep.name.progressFraction(), 0.16, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.language.progressFraction(), 0.33, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.loyaltyDecision.progressFraction(), 0.5, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.scannerPermission.progressFraction(), 0.66, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.scanning.progressFraction(), 0.66, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.manualCardEntry.progressFraction(), 0.66, accuracy: 0.001)
    }

    func testFinishStepsAreNearCompleteUntilSuccess() {
        XCTAssertEqual(OnboardingStep.creatingCard.progressFraction(), 0.85, accuracy: 0.001)
        XCTAssertEqual(OnboardingStep.processingScan.progressFraction(), 0.85, accuracy: 0.001)
        XCTAssertEqual(
            OnboardingStep.creatingCard.progressFraction(isFinishComplete: true),
            1.0,
            accuracy: 0.001
        )
        XCTAssertEqual(
            OnboardingStep.processingScan.progressFraction(isFinishComplete: true),
            1.0,
            accuracy: 0.001
        )
    }

    func testIsFinishCompleteDoesNotAffectEarlierSteps() {
        XCTAssertEqual(
            OnboardingStep.language.progressFraction(isFinishComplete: true),
            OnboardingStep.language.progressFraction()
        )
    }
}
