import XCTest
@testable import FeatureGame

final class FeatureGameTests: XCTestCase {
    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureGame.createScreen()
    }
}
