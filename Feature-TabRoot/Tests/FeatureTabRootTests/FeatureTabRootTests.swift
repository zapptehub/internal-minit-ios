import XCTest
@testable import FeatureTabRoot

final class FeatureTabRootTests: XCTestCase {
    func testAppTab_hasFiveTabsInDesignOrder() {
        XCTAssertEqual(
            AppTab.allCases.map(\.title),
            ["Home", "Offers", "Map", "Card", "Game"]
        )
    }

    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureTabRoot.createScreen(onLogOut: {})
    }
}
