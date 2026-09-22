import XCTest
@testable import FeatureLogin

final class AuthFlowLayoutTests: XCTestCase {
    func testFormWrapperUsesTheFigmaHorizontalInset() {
        XCTAssertEqual(AuthFlowStepLayout.horizontalInset, 20)
    }
}
