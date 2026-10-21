import CoreNetworking
import CoreNetworkingTestUtilities
import Foundation
import XCTest
@testable import DataLoyaltyCard

final class HttpLoyaltyCardRepositoryTests: XCTestCase {
    private let userID = "uid-loyalty-argument"

    func testCreateCardIsOnePostWithNoBodyAndTheServerCode() async throws {
        let card = try JSONDecoder().decode(
            LoyaltyCardResponse.self,
            from: ContractFixtures.bytes("loyalty-card.json")
        )
        let client = ScriptedNetworkClient(results: [.success(card)])
        let repository = HttpLoyaltyCardRepository(client: client)

        let created = try await repository.createCard(userId: userID)

        XCTAssertEqual(created.code, "MINIT-CONTRACT1")
        XCTAssertEqual(created.points, 3210)
        XCTAssertEqual(created.ownerUserId, userID)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].method, .POST)
        XCTAssertEqual(client.requests[0].path, "/v1/me/loyalty-card")
        XCTAssertNil(client.requests[0].body)
        assertUserIdWasNotSent(client)
    }

    func testClaimIsOnePostAndDoesNotCallLookup() async throws {
        let card = LoyaltyCardResponse(code: "MINIT-CONTRACT1", points: 3210, tierId: "silver")
        let client = ScriptedNetworkClient(results: [.success(card)])
        let repository = HttpLoyaltyCardRepository(client: client)

        let claimed = try await repository.claimCard(userId: userID, code: "  MINIT-CONTRACT1  ")

        XCTAssertEqual(claimed.code, "MINIT-CONTRACT1")
        XCTAssertEqual(claimed.ownerUserId, userID)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].method, .POST)
        XCTAssertEqual(client.requests[0].path, "/v1/loyalty-cards/MINIT-CONTRACT1/claim")
        XCTAssertNil(client.requests[0].body)
        XCTAssertFalse(client.requests.contains { $0.path == "/v1/loyalty-cards/MINIT-CONTRACT1" })
        assertUserIdWasNotSent(client)
    }

    func testClaimEncodesSpaceAndQuestionMarkAsOnePathSegment() async throws {
        let client = ScriptedNetworkClient(results: [
            .success(LoyaltyCardResponse(code: "A?B", points: 1, tierId: "silver")),
            .success(LoyaltyCardResponse(code: "A B", points: 1, tierId: "silver")),
        ])
        let repository = HttpLoyaltyCardRepository(client: client)

        _ = try await repository.claimCard(userId: userID, code: "A?B")
        _ = try await repository.claimCard(userId: userID, code: "  A B  ")

        XCTAssertEqual(client.requests.map(\.path), [
            "/v1/loyalty-cards/A%3FB/claim",
            "/v1/loyalty-cards/A%20B/claim",
        ])
        XCTAssertEqual(client.requests.map(\.method), [.POST, .POST])
        for path in client.requests.map(\.path) {
            let components = try XCTUnwrap(URLComponents(string: "https://api.minit.app" + path))
            XCTAssertNotNil(components.url)
            XCTAssertNil(components.query, path)
            XCTAssertNil(components.fragment, path)
        }
        assertUserIdWasNotSent(client)
    }

    func testClaimRejectsAnInvalidCodeBeforeAnyRequest() async {
        let client = ScriptedNetworkClient(results: [])
        let repository = HttpLoyaltyCardRepository(client: client)

        await assertLoyalty(.notFound) {
            _ = try await repository.claimCard(userId: self.userID, code: "SEED/001")
        }
        await assertLoyalty(.notFound) {
            _ = try await repository.claimCard(userId: self.userID, code: "   ")
        }
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testAlreadyRegisteredFromClaimIsAlreadyClaimedAfterOnePost() async throws {
        let client = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(409, try ContractFixtures.bytes("already-registered.json"))),
        ])
        let repository = HttpLoyaltyCardRepository(client: client)

        await assertLoyalty(.alreadyClaimed) {
            _ = try await repository.claimCard(userId: self.userID, code: "MINIT-CONTRACT1")
        }
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertTrue(client.requests[0].path.hasSuffix("/claim"))
    }

    func testCreateCardMapsAlreadyLinkedAfterOnePost() async throws {
        let client = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(409, try ContractFixtures.bytes("already-linked.json"))),
        ])

        await assertLoyalty(.alreadyLinked) {
            _ = try await HttpLoyaltyCardRepository(client: client).createCard(userId: self.userID)
        }
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].method, .POST)
        XCTAssertEqual(client.requests[0].path, "/v1/me/loyalty-card")
    }

    func testClaimMapsInvalidCodeAndNotFoundAfterOnePost() async throws {
        let invalidCode = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(400, try ContractFixtures.bytes("invalid-code.json"))),
        ])
        await assertLoyalty(.notFound) {
            _ = try await HttpLoyaltyCardRepository(client: invalidCode)
                .claimCard(userId: self.userID, code: "MINIT-CONTRACT1")
        }
        XCTAssertEqual(invalidCode.requests.count, 1)
        XCTAssertEqual(invalidCode.requests[0].method, .POST)
        XCTAssertTrue(invalidCode.requests[0].path.hasSuffix("/claim"))

        let missing = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(404, try ContractFixtures.bytes("not-found.json"))),
        ])
        await assertLoyalty(.notFound) {
            _ = try await HttpLoyaltyCardRepository(client: missing)
                .claimCard(userId: self.userID, code: "MINIT-CONTRACT1")
        }
        XCTAssertEqual(missing.requests.count, 1)
        XCTAssertTrue(missing.requests[0].path.hasSuffix("/claim"))
    }

    func testGatewayStatusesMapThroughRepositoryCalls() async throws {
        let create = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(502, Data())),
        ])
        await assertLoyalty(unavailable()) {
            _ = try await HttpLoyaltyCardRepository(client: create).createCard(userId: self.userID)
        }
        XCTAssertEqual(create.requests.count, 1)

        let linked = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(503, Data())),
        ])
        await assertLoyalty(unavailable()) {
            _ = try await HttpLoyaltyCardRepository(client: linked).fetchLinkedCard(userId: self.userID)
        }
        XCTAssertEqual(linked.requests.count, 1)

        let history = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(504, Data())),
        ])
        await assertLoyalty(unavailable()) {
            _ = try await HttpLoyaltyCardRepository(client: history)
                .fetchPointsHistory(limit: 20, cursor: nil)
        }
        XCTAssertEqual(history.requests.count, 1)
        XCTAssertEqual(history.requests[0].path, "/v1/me/points-history?limit=20")
    }

    func testBadRequestAndUnauthenticatedMapThroughTheRepository() async throws {
        let badRequest = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(400, try ContractFixtures.bytes("bad-request.json"))),
        ])
        await assertLoyalty(.underlying(.decoding)) {
            _ = try await HttpLoyaltyCardRepository(client: badRequest)
                .claimCard(userId: self.userID, code: "MINIT-CONTRACT1")
        }

        // The client retries a 401 once. This is the status it returns after that
        // refresh is exhausted. The repository maps it and does not send another request.
        let unauthenticated = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(401, try ContractFixtures.bytes("unauthenticated.json"))),
        ])
        await assertLoyalty(permissionDenied()) {
            _ = try await HttpLoyaltyCardRepository(client: unauthenticated)
                .createCard(userId: self.userID)
        }
        XCTAssertEqual(unauthenticated.requests.count, 1)
    }

    func testFetchLinkedCardReturnsNilOnlyFor404NotFound() async throws {
        let missing = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(404, try ContractFixtures.bytes("not-found.json"))),
        ])
        let card = try JSONDecoder().decode(
            LoyaltyCardResponse.self,
            from: ContractFixtures.bytes("loyalty-card.json")
        )
        let present = ScriptedNetworkClient(results: [.success(card)])
        let emptyStatus = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(404, Data())),
        ])

        let absent = try await HttpLoyaltyCardRepository(client: missing).fetchLinkedCard(userId: userID)
        XCTAssertNil(absent)

        let linked = try await HttpLoyaltyCardRepository(client: present).fetchLinkedCard(userId: userID)
        XCTAssertEqual(linked?.code, "MINIT-CONTRACT1")
        XCTAssertEqual(linked?.points, 3210)
        XCTAssertEqual(linked?.ownerUserId, userID)
        XCTAssertEqual(present.requests[0].method, .GET)
        XCTAssertEqual(present.requests[0].path, "/v1/me/loyalty-card")

        await assertLoyalty(.underlying(.unknown)) {
            _ = try await HttpLoyaltyCardRepository(client: emptyStatus).fetchLinkedCard(userId: self.userID)
        }
        assertUserIdWasNotSent(missing)
        assertUserIdWasNotSent(present)
    }

    func testPointsHistorySendsLimitAndAnEncodedCursor() async throws {
        let firstPage = try JSONDecoder().decode(
            PointsHistoryResponse.self,
            from: ContractFixtures.bytes("points-history.json")
        )
        let nextPage = try JSONDecoder().decode(
            PointsHistoryResponse.self,
            from: ContractFixtures.bytes("points-history-page.json")
        )
        let client = ScriptedNetworkClient(results: [
            .success(firstPage),
            .success(nextPage),
            .success(firstPage),
        ])
        let repository: LoyaltyCardRepository = HttpLoyaltyCardRepository(client: client)

        let first = try await repository.fetchPointsHistory(limit: 20, cursor: nil)
        let second = try await repository.fetchPointsHistory(limit: 20, cursor: "a b")
        _ = try await repository.fetchPointsHistory(limit: 20, cursor: "a&b=c")

        XCTAssertEqual(first.items.first?.delta, 3210)
        XCTAssertEqual(first.items.first?.reason.en, "Starting balance")
        XCTAssertNil(first.nextCursor)
        XCTAssertEqual(second.nextCursor, nextPage.nextCursor)
        XCTAssertEqual(client.requests[0].path, "/v1/me/points-history?limit=20")
        XCTAssertEqual(client.requests[1].path, "/v1/me/points-history?limit=20&cursor=a%20b")
        XCTAssertEqual(client.requests.map(\.method), [.GET, .GET, .GET])

        let components = try XCTUnwrap(
            URLComponents(string: "https://api.minit.app" + client.requests[2].path)
        )
        XCTAssertEqual(components.queryItems?.map(\.name), ["limit", "cursor"])
        XCTAssertEqual(components.queryItems?.last?.value, "a&b=c")
        assertUserIdWasNotSent(client)
    }

    func testPointsHistoryFeedsTheResponseCursorIntoTheNextRequest() async throws {
        let firstResponse = try JSONDecoder().decode(
            PointsHistoryResponse.self,
            from: ContractFixtures.bytes("points-history-page.json")
        )
        let lastResponse = try JSONDecoder().decode(
            PointsHistoryResponse.self,
            from: ContractFixtures.bytes("points-history.json")
        )
        let fixtureCursor =
            "MjAyNC0wNi0wMVQwMDowMDowMC4wMDAwMDFafDAwMDAwMDAwLTAwMDAtNDAwMC04MDAwLTAwMDAwMDAwMDAwMg"
        XCTAssertEqual(firstResponse.nextCursor, fixtureCursor)
        XCTAssertNil(lastResponse.nextCursor)

        let client = ScriptedNetworkClient(results: [
            .success(firstResponse),
            .success(lastResponse),
        ])
        let repository: LoyaltyCardRepository = HttpLoyaltyCardRepository(client: client)

        var cursor: String?
        var pages: [PointsHistoryPage] = []
        repeat {
            let page = try await repository.fetchPointsHistory(limit: 20, cursor: cursor)
            pages.append(page)
            cursor = page.nextCursor
        } while cursor != nil && pages.count < 3

        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].nextCursor, fixtureCursor)
        XCTAssertNil(pages[1].nextCursor)
        XCTAssertNil(cursor)
        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(client.requests[0].path, "/v1/me/points-history?limit=20")
        XCTAssertEqual(
            client.requests[1].path,
            "/v1/me/points-history?limit=20&cursor=\(fixtureCursor)"
        )
        assertUserIdWasNotSent(client)
    }

    func testPointsHistoryCoercesLimitInto1To50() async throws {
        let page = try JSONDecoder().decode(
            PointsHistoryResponse.self,
            from: ContractFixtures.bytes("points-history.json")
        )
        let client = ScriptedNetworkClient(results: [
            .success(page),
            .success(page),
            .success(page),
            .success(page),
            .success(page),
        ])
        let repository = HttpLoyaltyCardRepository(client: client)

        _ = try await repository.fetchPointsHistory(limit: 0, cursor: nil)
        _ = try await repository.fetchPointsHistory(limit: 1, cursor: nil)
        _ = try await repository.fetchPointsHistory(limit: 50, cursor: nil)
        _ = try await repository.fetchPointsHistory(limit: 51, cursor: nil)
        _ = try await repository.fetchPointsHistory(limit: 100, cursor: nil)

        XCTAssertEqual(client.requests[0].path, "/v1/me/points-history?limit=1")
        XCTAssertEqual(client.requests[1].path, "/v1/me/points-history?limit=1")
        XCTAssertEqual(client.requests[2].path, "/v1/me/points-history?limit=50")
        XCTAssertEqual(client.requests[3].path, "/v1/me/points-history?limit=50")
        XCTAssertEqual(client.requests[4].path, "/v1/me/points-history?limit=50")
    }

    func testPointsHistoryReturnsAnEmptyPageWhenTheCallerHasNoCard() async throws {
        let client = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(404, try ContractFixtures.bytes("not-found.json"))),
        ])

        let page = try await HttpLoyaltyCardRepository(client: client)
            .fetchPointsHistory(limit: 20, cursor: nil)

        XCTAssertEqual(page, PointsHistoryPage(items: [], nextCursor: nil))
        XCTAssertEqual(client.requests[0].path, "/v1/me/points-history?limit=20")
    }

    func testPointsHistoryMapsAFailureThatIsNot404NotFound() async throws {
        let serverError = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(
                500,
                Data(#"{"error":{"code":"internal","message":"Internal server error"}}"#.utf8)
            )),
        ])
        await assertLoyalty(.underlying(.unknown)) {
            _ = try await HttpLoyaltyCardRepository(client: serverError)
                .fetchPointsHistory(limit: 20, cursor: nil)
        }

        let proxyMiss = ScriptedNetworkClient(results: [
            .failure(NetworkError.statusCode(404, Data("<html></html>".utf8))),
        ])
        await assertLoyalty(.underlying(.unknown)) {
            _ = try await HttpLoyaltyCardRepository(client: proxyMiss)
                .fetchPointsHistory(limit: 20, cursor: nil)
        }
    }

    func testCancellationIsNotMapped() async {
        let client = ScriptedNetworkClient(results: [.failure(CancellationError())])
        let repository = HttpLoyaltyCardRepository(client: client)

        do {
            _ = try await repository.createCard(userId: userID)
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTransportAndDecodingFailuresMapThroughTheRepository() async {
        let offline = ScriptedNetworkClient(results: [
            .failure(URLError(.notConnectedToInternet)),
        ])
        await assertLoyalty(.underlying(.unknown)) {
            _ = try await HttpLoyaltyCardRepository(client: offline).createCard(userId: self.userID)
        }

        let decoding = ScriptedNetworkClient(results: [
            .failure(NetworkError.decodingFailed(SampleFailure())),
        ])
        await assertLoyalty(.underlying(.decoding)) {
            _ = try await HttpLoyaltyCardRepository(client: decoding).createCard(userId: self.userID)
        }
    }

    func testDataModuleConstructsHttpOnlyForTheHttpId() throws {
        let firebase = LoyaltyCardDataModule(
            dataBackend: "firebase",
            networkClient: ScriptedNetworkClient(results: [])
        )
        let firebaseRepository = try XCTUnwrap(
            firebase.makeLoyaltyCardRepository() as? LoyaltyCardRepositoryImpl
        )
        let firebaseAgain = try XCTUnwrap(
            firebase.makeLoyaltyCardRepository() as? LoyaltyCardRepositoryImpl
        )
        XCTAssertTrue(firebaseRepository === firebaseAgain)
        XCTAssertTrue(LoyaltyCardDataModule().makeLoyaltyCardRepository() is LoyaltyCardRepositoryImpl)

        let client = ScriptedNetworkClient(results: [])
        let http = LoyaltyCardDataModule(dataBackend: " http ", networkClient: client)
        let httpRepository = try XCTUnwrap(http.makeLoyaltyCardRepository() as? HttpLoyaltyCardRepository)
        let httpAgain = try XCTUnwrap(http.makeLoyaltyCardRepository() as? HttpLoyaltyCardRepository)
        XCTAssertTrue(httpRepository === httpAgain)
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
            XCTAssertNil(request.body, file: file, line: line)
        }
    }

    private func assertLoyalty(
        _ expected: LoyaltyCardError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected \(expected) but got \(error)", file: file, line: line)
        }
    }
}

private func permissionDenied() -> LoyaltyCardError {
    .underlying(.database(
        domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
        code: LoyaltyCardError.Underlying.firebasePermissionDeniedCode
    ))
}

private func unavailable() -> LoyaltyCardError {
    .underlying(.database(
        domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
        code: LoyaltyCardError.Underlying.firebaseUnavailableCode
    ))
}

private struct SampleFailure: Error {}

private struct RecordedRequest {
    let path: String
    let method: HTTPMethod
    let body: Any?
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
        try dispatch(path: path, method: method, body: nil)
    }

    func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: B
    ) async throws -> T {
        try dispatch(path: path, method: method, body: body)
    }

    func data(_: URL) async throws -> Data {
        throw NetworkError.invalidURL
    }

    private func dispatch<T>(path: String, method: HTTPMethod, body: Any?) throws -> T {
        requests.append(RecordedRequest(path: path, method: method, body: body))
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
