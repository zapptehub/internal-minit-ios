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

    func testSaveProfileForwardsAllFieldsAsProfileDto() async throws {
        let api = FakeProfileApi()
        let repository = ProfileRepositoryImpl(api: api)

        try await repository.saveProfile(userId: "u1", name: "Iveta", surname: "Nováková", email: "iveta@minitbakery.com")

        XCTAssertEqual(api.savedUserId, "u1")
        XCTAssertEqual(api.savedProfile, ProfileDto(name: "Iveta", surname: "Nováková", email: "iveta@minitbakery.com"))
        XCTAssertNil(api.updatedUserId)
    }

    func testSaveProfilePropagatesApiErrors() async {
        let api = FakeProfileApi()
        api.saveProfileError = NSError(domain: "test", code: 1)
        let repository = ProfileRepositoryImpl(api: api)

        do {
            try await repository.saveProfile(userId: "u1", name: "Iveta", surname: "Nováková", email: "iveta@minitbakery.com")
            XCTFail("Expected error to be thrown")
        } catch {
            // expected
        }
    }

    func testFetchProfileMapsDtoToDomainModelWhenFound() async throws {
        let api = FakeProfileApi()
        api.profileToReturn = ProfileDto(name: "Iveta", surname: "Nováková", email: "iveta@minitbakery.com")
        let repository = ProfileRepositoryImpl(api: api)

        let result = try await repository.fetchProfile(userId: "u1")

        XCTAssertEqual(api.fetchedUserId, "u1")
        XCTAssertEqual(result, ProfileData(name: "Iveta", surname: "Nováková", email: "iveta@minitbakery.com"))
    }

    func testFetchProfileReturnsNilWhenApiHasNoRecord() async throws {
        let api = FakeProfileApi()
        api.profileToReturn = nil
        let repository = ProfileRepositoryImpl(api: api)

        let result = try await repository.fetchProfile(userId: "u1")

        XCTAssertNil(result)
    }

    func testFetchProfilePropagatesApiErrors() async {
        let api = FakeProfileApi()
        api.fetchProfileError = NSError(domain: "test", code: 1)
        let repository = ProfileRepositoryImpl(api: api)

        do {
            _ = try await repository.fetchProfile(userId: "u1")
            XCTFail("Expected error to be thrown")
        } catch {
            // expected
        }
    }
}

private final class FakeProfileApi: ProfileApi, @unchecked Sendable {
    var savedProfile: ProfileDto?
    var savedUserId: String?
    var saveProfileError: Error?

    var updatedUserId: String?
    var updatedName: String?

    var fetchedUserId: String?
    var profileToReturn: ProfileDto?
    var fetchProfileError: Error?

    func saveProfile(userId: String, profile: ProfileDto) async throws {
        if let saveProfileError { throw saveProfileError }
        savedUserId = userId
        savedProfile = profile
    }

    func updateName(userId: String, name: String) async throws {
        updatedUserId = userId
        updatedName = name
    }

    func fetchProfile(userId: String) async throws -> ProfileDto? {
        if let fetchProfileError { throw fetchProfileError }
        fetchedUserId = userId
        return profileToReturn
    }
}
