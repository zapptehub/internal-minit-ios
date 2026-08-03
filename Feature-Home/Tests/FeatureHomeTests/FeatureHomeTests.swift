import DataProfile
import XCTest
@testable import FeatureHome

final class FeatureHomeTests: XCTestCase {
    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureHome.createScreen(
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
