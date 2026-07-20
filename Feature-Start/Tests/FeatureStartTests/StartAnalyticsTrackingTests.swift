import XCTest
@testable import FeatureStart

final class StartAnalyticsTrackingTests: XCTestCase {
    func testMock_recordsScreenOpenedAndGetStartedEvents() {
        let mock = MockStartAnalyticsTracking()

        mock.trackScreenOpened()
        mock.trackGetStartedTapped()

        XCTAssertTrue(mock.screenOpenedCalled)
        XCTAssertTrue(mock.getStartedTappedCalled)
    }
}

private final class MockStartAnalyticsTracking: StartAnalyticsTracking {
    var screenOpenedCalled = false
    var getStartedTappedCalled = false

    func trackScreenOpened(file: String = #fileID) {
        screenOpenedCalled = true
    }

    func trackGetStartedTapped(file: String = #fileID) {
        getStartedTappedCalled = true
    }
}
