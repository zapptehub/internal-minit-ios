import XCTest
@testable import FeatureOffers

final class FeatureOffersTests: XCTestCase {
    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureOffers.createScreen()
    }
}
