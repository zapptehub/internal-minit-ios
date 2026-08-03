import XCTest
@testable import FeatureMap

final class FeatureMapTests: XCTestCase {
    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureMap.createScreen()
    }
}
