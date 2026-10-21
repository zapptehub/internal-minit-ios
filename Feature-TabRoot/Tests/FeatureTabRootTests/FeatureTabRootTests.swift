import CoreNetworking
import DataProfile
import FeatureHome
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
            homeRepository: FirebaseHomeRepository(),
            networkClient: UnusedTabNetworkClient(),
            apiBaseURL: "https://api.minit.app",
            onLogOut: {}
        )
    }
}

private struct UnusedTabNetworkClient: NetworkClient {
    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        throw NetworkError.invalidURL
    }

    func request<T: Decodable, B: Encodable>(_ path: String, method: HTTPMethod, body: B) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ url: URL) async throws -> Data {
        throw NetworkError.invalidURL
    }
}

private struct StubProfileRepository: ProfileRepository {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? { nil }
}
