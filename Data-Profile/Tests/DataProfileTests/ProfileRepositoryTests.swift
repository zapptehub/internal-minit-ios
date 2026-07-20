import XCTest
@testable import DataProfile

final class ProfileRepositoryTests: XCTestCase {
    func testUpdateNameUsesNarrowProfileApiOperation() async throws {
        let api = FakeProfileApi()
        let repository = ProfileRepositoryImpl(api: api)

        try await repository.updateName(userId: "u1", name: "Iveta")

        XCTAssertEqual(api.updatedUserId, "u1")
        XCTAssertEqual(api.updatedName, "Iveta")
        XCTAssertNil(api.savedProfile)
    }
}

private final class FakeProfileApi: ProfileApi, @unchecked Sendable {
    var savedProfile: ProfileDto?
    var updatedUserId: String?
    var updatedName: String?

    func saveProfile(userId: String, profile: ProfileDto) async throws {
        savedProfile = profile
    }

    func updateName(userId: String, name: String) async throws {
        updatedUserId = userId
        updatedName = name
    }

    func fetchProfile(userId: String) async throws -> ProfileDto? { nil }
}
