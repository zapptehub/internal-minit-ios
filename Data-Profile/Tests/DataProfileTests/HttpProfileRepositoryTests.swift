import CoreNetworking
import CoreNetworkingTestUtilities
import Foundation
import XCTest
@testable import DataProfile

final class HttpProfileRepositoryTests: XCTestCase {
    private let userID = "uid-profile-argument"

    func testProfileFixtureDecodesSixKeysAndTheAvatarURL() throws {
        let data = try ContractFixtures.bytes("profile.json")
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(
            Set(object.keys),
            ["id", "name", "surname", "email", "loyaltyCardId", "avatarUrl"]
        )

        let profile = try JSONDecoder().decode(ProfileResponse.self, from: data)
        XCTAssertEqual(profile.id, "uid-profile")
        XCTAssertEqual(profile.name, "Iveta")
        XCTAssertEqual(profile.surname, "Ozola")
        XCTAssertEqual(profile.email, "iveta@example.com")
        XCTAssertNil(profile.loyaltyCardId)
        XCTAssertEqual(profile.avatarUrl, "http://127.0.0.1:8080/v1/media/avatars/default.webp")
        XCTAssertEqual(
            profile.toModel(),
            ProfileData(
                name: "Iveta",
                surname: "Ozola",
                email: "iveta@example.com",
                avatarUrl: "http://127.0.0.1:8080/v1/media/avatars/default.webp"
            )
        )
    }

    func testLinkedProfileFixtureKeepsTheLoyaltyCardId() throws {
        let profile = try JSONDecoder().decode(
            ProfileResponse.self,
            from: ContractFixtures.bytes("profile-linked.json")
        )
        XCTAssertEqual(profile.loyaltyCardId, "MINIT-CONTRACT1")
        XCTAssertEqual(profile.toModel().name, "Iveta")
        XCTAssertTrue(profile.toModel().avatarUrl?.hasSuffix("/v1/media/avatars/default.webp") == true)
    }

    func testSavePatchBodyEncodesNameSurnameAndEmailOnly() throws {
        let body = ProfilePatchBody(name: "Iveta", surname: "Ozola", email: "iveta@example.com")
        let object = try jsonObject(body)
        XCTAssertEqual(Set(object.keys), ["name", "surname", "email"])
        XCTAssertEqual(object["name"], "Iveta")
        XCTAssertEqual(object["surname"], "Ozola")
        XCTAssertEqual(object["email"], "iveta@example.com")
    }

    func testNamePatchBodyEncodesNameOnly() throws {
        let object = try jsonObject(ProfileNamePatchBody(name: "Iveta"))
        XCTAssertEqual(object, ["name": "Iveta"])
    }

    func testFetchProfileSetsTheAvatarURLFromTheBody() async throws {
        let profile = try JSONDecoder().decode(
            ProfileResponse.self,
            from: ContractFixtures.bytes("profile.json")
        )
        let client = ScriptedNetworkClient(results: [.success(profile)])
        let repository = HttpProfileRepository(client: client)

        let fetched = try await repository.fetchProfile(userId: userID)

        XCTAssertEqual(fetched?.name, "Iveta")
        XCTAssertEqual(fetched?.avatarUrl, profile.avatarUrl)
        XCTAssertEqual(client.requests.map(\.method), [.GET])
        XCTAssertEqual(client.requests.map(\.path), ["/v1/me"])
        XCTAssertNil(client.requests[0].body)
        assertUserIdWasNotSent(client)
    }

    func testUpdateNameGetsTheRowThenPatchesNameOnly() async throws {
        let profile = try sampleProfile()
        let client = ScriptedNetworkClient(results: [.success(profile), .success(profile)])
        let repository = HttpProfileRepository(client: client)

        try await repository.updateName(userId: userID, name: "Petra")

        XCTAssertEqual(client.requests.map(\.method), [.GET, .PATCH])
        XCTAssertEqual(client.requests.map(\.path), ["/v1/me", "/v1/me"])
        let body = try XCTUnwrap(client.requests[1].body as? ProfileNamePatchBody)
        XCTAssertEqual(body, ProfileNamePatchBody(name: "Petra"))
        let encoded = try jsonObject(body)
        XCTAssertEqual(encoded, ["name": "Petra"])
        assertUserIdWasNotSent(client)
    }

    func testAFailedGetDoesNotPatch() async throws {
        let client = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(404, try ContractFixtures.bytes("not-found.json"))),
        ])
        let repository = HttpProfileRepository(client: client)

        do {
            try await repository.updateName(userId: userID, name: "Petra")
            XCTFail("Expected the GET error")
        } catch let error as NetworkError {
            guard case .statusCode(404, _) = error else {
                XCTFail("Expected 404, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected NetworkError, got \(error)")
        }
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].method, .GET)
    }

    func testUpdateNameSendsThePatchAndThrowsWhenThePatchFails() async throws {
        let profile = try sampleProfile()
        let unauthorized = ScriptedNetworkClient(results: [
            .success(profile),
            .failure(NetworkError.statusCode(401, try ContractFixtures.bytes("unauthenticated.json"))),
        ])
        await assertStatusCode(401) {
            try await HttpProfileRepository(client: unauthorized)
                .updateName(userId: self.userID, name: "Petra")
        }
        XCTAssertEqual(unauthorized.requests.map(\.method), [.GET, .PATCH])
        XCTAssertEqual(unauthorized.requests.map(\.path), ["/v1/me", "/v1/me"])
        let nameBody = try XCTUnwrap(unauthorized.requests[1].body as? ProfileNamePatchBody)
        XCTAssertEqual(nameBody, ProfileNamePatchBody(name: "Petra"))
        assertUserIdWasNotSent(unauthorized)

        let unavailable = ScriptedNetworkClient(results: [
            .success(profile),
            .failure(NetworkError.statusCode(503, Data())),
        ])
        await assertStatusCode(503) {
            try await HttpProfileRepository(client: unavailable)
                .updateName(userId: self.userID, name: "Petra")
        }
        XCTAssertEqual(unavailable.requests.map(\.method), [.GET, .PATCH])
        XCTAssertEqual(unavailable.requests.count, 2)
        assertUserIdWasNotSent(unavailable)
    }

    func testCancellationIsNotMapped() async {
        let client = ScriptedNetworkClient(results: [.failure(CancellationError())])
        let repository = HttpProfileRepository(client: client)

        do {
            _ = try await repository.fetchProfile(userId: userID)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDataModuleConstructsHttpOnlyForTheHttpId() throws {
        let firebase = ProfileDataModule(
            dataBackend: "firebase",
            networkClient: ScriptedNetworkClient(results: [])
        )
        let firebaseRepository = try XCTUnwrap(firebase.makeProfileRepository() as? ProfileRepositoryImpl)
        let firebaseAgain = try XCTUnwrap(firebase.makeProfileRepository() as? ProfileRepositoryImpl)
        XCTAssertTrue(firebaseRepository === firebaseAgain)
        XCTAssertTrue(ProfileDataModule().makeProfileRepository() is ProfileRepositoryImpl)

        let http = ProfileDataModule(dataBackend: " http ", networkClient: ScriptedNetworkClient(results: []))
        let httpRepository = try XCTUnwrap(http.makeProfileRepository() as? HttpProfileRepository)
        let httpAgain = try XCTUnwrap(http.makeProfileRepository() as? HttpProfileRepository)
        XCTAssertTrue(httpRepository === httpAgain)
    }

    private func sampleProfile() throws -> ProfileResponse {
        try JSONDecoder().decode(ProfileResponse.self, from: ContractFixtures.bytes("profile.json"))
    }

    private func jsonObject<T: Encodable>(_ body: T) throws -> [String: String] {
        let data = try JSONEncoder().encode(body)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    private func assertStatusCode(
        _ status: Int,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("Expected status \(status)", file: file, line: line)
        } catch let error as NetworkError {
            guard case .statusCode(let code, _) = error, code == status else {
                XCTFail("Expected \(status), got \(error)", file: file, line: line)
                return
            }
        } catch {
            XCTFail("Expected NetworkError, got \(error)", file: file, line: line)
        }
    }

    private func assertUserIdWasNotSent(
        _ client: ScriptedNetworkClient,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for request in client.requests {
            XCTAssertFalse(request.path.contains(userID), request.path, file: file, line: line)
            let components = URLComponents(string: "https://api.minit.app" + request.path)
            XCTAssertFalse(
                components?.percentEncodedQuery?.contains(userID) == true,
                components?.percentEncodedQuery ?? "",
                file: file,
                line: line
            )
            for item in components?.queryItems ?? [] {
                XCTAssertFalse(item.name.contains(userID), item.name, file: file, line: line)
                XCTAssertFalse(item.value?.contains(userID) == true, item.value ?? "", file: file, line: line)
            }
            if let encodedBody = request.encodedBody {
                let text = String(decoding: encodedBody, as: UTF8.self)
                XCTAssertFalse(text.contains(userID), text, file: file, line: line)
            }
        }
    }
}

private struct RecordedRequest {
    let path: String
    let method: HTTPMethod
    let body: Any?
    let encodedBody: Data?
}

private enum ScriptedResult {
    case success(Any)
    case failure(Error)
}

private final class ScriptedNetworkClient: NetworkClient, @unchecked Sendable {
    private(set) var requests: [RecordedRequest] = []
    private var results: [ScriptedResult]

    init(results: [ScriptedResult]) {
        self.results = results
    }

    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        try dispatch(path: path, method: method, body: nil, encodedBody: nil)
    }

    func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: B
    ) async throws -> T {
        try dispatch(
            path: path,
            method: method,
            body: body,
            encodedBody: try JSONEncoder().encode(body)
        )
    }

    func data(_: URL) async throws -> Data {
        throw NetworkError.invalidURL
    }

    private func dispatch<T>(
        path: String,
        method: HTTPMethod,
        body: Any?,
        encodedBody: Data?
    ) throws -> T {
        requests.append(RecordedRequest(
            path: path,
            method: method,
            body: body,
            encodedBody: encodedBody
        ))
        guard !results.isEmpty else {
            XCTFail("no scripted result for \(method.rawValue) \(path)")
            throw NetworkError.invalidResponse
        }
        let result = results.removeFirst()
        switch result {
        case .failure(let error):
            throw error
        case .success(let value):
            guard let typed = value as? T else {
                XCTFail("Expected \(T.self) but scripted \(type(of: value))")
                throw NetworkError.invalidResponse
            }
            return typed
        }
    }
}
