import XCTest
@testable import FeatureCard

final class FeatureCardTests: XCTestCase {
    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureCard.createScreen()
    }
}
