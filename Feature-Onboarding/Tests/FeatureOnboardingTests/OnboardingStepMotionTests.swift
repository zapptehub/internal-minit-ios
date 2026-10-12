import XCTest
@testable import FeatureOnboarding

final class OnboardingStepMotionTests: XCTestCase {
    func testReduceMotionSnapsTheStepInPlace() {
        XCTAssertEqual(
            OnboardingStepMotion.resolve(direction: .forward, reduceMotion: true),
            .snap
        )
        XCTAssertEqual(
            OnboardingStepMotion.resolve(direction: .backward, reduceMotion: true),
            .snap
        )
        XCTAssertNil(OnboardingStepMotion.snap.animation)
    }

    func testStepSlidesWhenReduceMotionIsOff() {
        XCTAssertEqual(
            OnboardingStepMotion.resolve(direction: .forward, reduceMotion: false),
            .slideForward
        )
        XCTAssertEqual(
            OnboardingStepMotion.resolve(direction: .backward, reduceMotion: false),
            .slideBackward
        )
        XCTAssertNotNil(OnboardingStepMotion.slideForward.animation)
        XCTAssertNotNil(OnboardingStepMotion.slideBackward.animation)
    }
}
