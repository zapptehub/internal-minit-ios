import XCTest
@testable import FeatureHome

final class FeatureHomeTests: XCTestCase {
    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureHome.createScreen(onLogOut: {})
    }
}
