import DataProfile
import XCTest
@testable import FeatureTabRoot

final class FeatureTabRootTests: XCTestCase {
    func testAppTab_hasFiveTabsInDesignOrder() {
        XCTAssertEqual(
            AppTab.allCases.map(\.titleKey),
            [
                "common.tabName.home",
                "common.tabName.offers",
                "common.tabName.map",
                "common.tabName.card",
                "common.tabName.game"
            ]
        )
    }

    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureTabRoot.createScreen(
            userId: "user-1",
            profileRepository: StubProfileRepository(),
            onLogOut: {}
        )
    }
}

private struct StubProfileRepository: ProfileRepository {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? { nil }
}
