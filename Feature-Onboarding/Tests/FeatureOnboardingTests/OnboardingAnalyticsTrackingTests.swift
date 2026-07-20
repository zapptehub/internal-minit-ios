import XCTest
import OnboardingTestUtilities
@testable import FeatureOnboarding

final class OnboardingAnalyticsTrackingTests: XCTestCase {
    func testMock_recordsScreenViewAndSelectionEvents() {
        let mock = MockOnboardingAnalyticsTracking()

        mock.trackNameScreenViewed()
        mock.trackLanguageSelected(languageCode: "sk")
        mock.trackLoyaltyBranchSelected(branch: "newCustomer")
        mock.trackOnboardingCompleted()

        XCTAssertTrue(mock.trackNameScreenViewedCalled)
        XCTAssertTrue(mock.trackLanguageSelectedCalled)
        XCTAssertEqual(mock.trackLanguageSelectedCode, "sk")
        XCTAssertTrue(mock.trackLoyaltyBranchSelectedCalled)
        XCTAssertEqual(mock.trackLoyaltyBranchSelectedBranch, "newCustomer")
        XCTAssertTrue(mock.trackOnboardingCompletedCalled)
    }

    func testMock_recordsCreateAndClaimFailures() {
        let mock = MockOnboardingAnalyticsTracking()

        mock.trackCreateCardFailed(reason: "network")
        mock.trackClaimCardFailed(reason: "alreadyClaimed", source: "scanner")

        XCTAssertTrue(mock.trackCreateCardFailedCalled)
        XCTAssertEqual(mock.trackCreateCardFailedReason, "network")
        XCTAssertTrue(mock.trackClaimCardFailedCalled)
        XCTAssertEqual(mock.trackClaimCardFailedReason, "alreadyClaimed")
        XCTAssertEqual(mock.trackClaimCardFailedSource, "scanner")
    }
}
