import CoreNetworking
import CoreNetworkingTestUtilities
import XCTest
@testable import DataLoyaltyCard

/// HTTP contract for `HttpLoyaltyCardRepository`.
///
/// Skipped unless `MINIT_HTTP_CONTRACT` is `1`. The client calls
/// `http://127.0.0.1:8080`. `setUp` posts `/v1/test/reset`. Create expects
/// 3210 points. A plain pair races claim and create; there is no barrier.
/// This class imports neither FirebaseAuth nor FirebaseDatabase.
final class HttpLoyaltyCardContractTests: XCTestCase {
    private let expectedPoints = 3210

    override func setUp() async throws {
        try XCTSkipUnless(
            HttpContract.isEnabled,
            "HTTP contract is opt-in. Set MINIT_HTTP_CONTRACT=1 to call http://127.0.0.1:8080."
        )
        try await ContractHTTPClient(subject: "loyalty-reset").reset()
    }

    func testTwoTasksRaceClaimOnSeed001() async throws {
        let first = open("loyalty-claim-a")
        let second = open("loyalty-claim-b")
        XCTAssertFalse(first.repository === second.repository)

        let firstTask = Task { await outcome { try await first.repository.claimCard(userId: first.subject, code: "SEED-001") } }
        let secondTask = Task { await outcome { try await second.repository.claimCard(userId: second.subject, code: "SEED-001") } }
        let results = await [firstTask.value, secondTask.value]
        let won = results.compactMap { try? $0.get() }
        let errors = loyaltyErrors(in: results)

        XCTAssertEqual(won.count, 1, describe(results))
        XCTAssertEqual(errors, [.alreadyClaimed], describe(results))
        let winner = try XCTUnwrap(won.first)
        XCTAssertEqual(winner.code, "SEED-001")
        XCTAssertEqual(winner.points, expectedPoints)
        let winnerSession = winner.ownerUserId == first.subject ? first : second
        let loserSession = winnerSession.subject == first.subject ? second : first
        let winnerCard = try await winnerSession.repository.fetchLinkedCard(userId: winnerSession.subject)
        let loserCard = try await loserSession.repository.fetchLinkedCard(userId: loserSession.subject)
        XCTAssertEqual(winnerCard, winner)
        XCTAssertNil(loserCard)
    }

    func testTwoSessionsOfOneUserRaceCreateCardAndFinishWithOneCard() async throws {
        let subject = "loyalty-create-race"
        let first = open(subject)
        let second = open(subject)
        XCTAssertEqual(first.subject, second.subject)
        XCTAssertFalse(first.repository === second.repository)

        let firstTask = Task { await outcome { try await first.repository.createCard(userId: subject) } }
        let secondTask = Task { await outcome { try await second.repository.createCard(userId: subject) } }
        let results = await [firstTask.value, secondTask.value]
        let cards = results.compactMap { try? $0.get() }

        XCTAssertEqual(cards.count, 2, describe(results))
        guard cards.count == 2 else { return }
        XCTAssertEqual(cards[0].code, cards[1].code)
        XCTAssertEqual(cards[0].points, expectedPoints)
        XCTAssertEqual(cards[1].points, expectedPoints)
        XCTAssertEqual(cards[0].ownerUserId, subject)
        XCTAssertEqual(cards[1].ownerUserId, subject)
        let firstCard = try await first.repository.fetchLinkedCard(userId: subject)
        let secondCard = try await second.repository.fetchLinkedCard(userId: subject)
        XCTAssertEqual(firstCard, cards[0])
        XCTAssertEqual(secondCard, cards[0])
    }

    func testSecondSeedClaimIsAlreadyLinkedAndTheLoserStaysUnowned() async throws {
        let session = open("loyalty-two-seeds")
        let won = try await session.repository.claimCard(userId: session.subject, code: "SEED-001")
        XCTAssertEqual(won.code, "SEED-001")
        XCTAssertEqual(won.ownerUserId, session.subject)
        XCTAssertEqual(won.points, expectedPoints)

        await assertLoyalty(.alreadyLinked) {
            _ = try await session.repository.claimCard(userId: session.subject, code: "SEED-002")
        }

        let other = open("loyalty-two-seeds-other")
        let taken = try await other.repository.claimCard(userId: other.subject, code: "SEED-002")
        XCTAssertEqual(taken.code, "SEED-002")
        XCTAssertEqual(taken.ownerUserId, other.subject)
        XCTAssertEqual(taken.points, expectedPoints)
        let kept = try await session.repository.fetchLinkedCard(userId: session.subject)
        let otherCard = try await other.repository.fetchLinkedCard(userId: other.subject)
        XCTAssertEqual(kept, won)
        XCTAssertEqual(otherCard, taken)
    }

    func testSecondUserClaimingTheCreatedCodeIsAlreadyClaimed() async throws {
        let owner = open("loyalty-owner")
        let created = try await owner.repository.createCard(userId: owner.subject)
        XCTAssertEqual(created.points, expectedPoints)
        XCTAssertEqual(created.ownerUserId, owner.subject)
        XCTAssertTrue(created.code.hasPrefix("MINIT-"))

        let intruder = open("loyalty-intruder")
        await assertLoyalty(.alreadyClaimed) {
            _ = try await intruder.repository.claimCard(userId: intruder.subject, code: created.code)
        }
        let ownerCard = try await owner.repository.fetchLinkedCard(userId: owner.subject)
        let intruderCard = try await intruder.repository.fetchLinkedCard(userId: intruder.subject)
        XCTAssertEqual(ownerCard, created)
        XCTAssertNil(intruderCard)
    }

    func testCreateCardThenFetchLinkedCardReturnsThatCardAt3210() async throws {
        let session = open("loyalty-create-read")
        let created = try await session.repository.createCard(userId: session.subject)
        XCTAssertEqual(created.points, expectedPoints)
        XCTAssertEqual(created.ownerUserId, session.subject)
        XCTAssertTrue(created.code.hasPrefix("MINIT-"))
        let linked = try await session.repository.fetchLinkedCard(userId: session.subject)
        XCTAssertEqual(linked, created)
    }

    func testCallWithNoSessionIsRejected() async throws {
        let client = ContractHTTPClient(subject: nil)
        do {
            let _: DiscardedBody = try await client.request("/v1/me/loyalty-card", method: .GET)
            XCTFail("GET /v1/me/loyalty-card without a session was not rejected")
        } catch let error as NetworkError {
            assertStatus401MapsToPermissionDenied(error)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw error
        } catch {
            XCTFail("expected NetworkError.statusCode(401, _); threw \(error)")
        }

        await assertLoyalty(permissionDenied()) {
            _ = try await HttpLoyaltyCardRepository(client: client).createCard(userId: "no-session")
        }
    }

    private func open(_ subject: String) -> LoyaltySession {
        LoyaltySession(
            subject: subject,
            repository: HttpLoyaltyCardRepository(client: ContractHTTPClient(subject: subject))
        )
    }

    /// Live 401 from a missing session, mapped the same way the repository maps it.
    private func assertStatus401MapsToPermissionDenied(_ error: NetworkError) {
        guard case .statusCode(let status, _) = error else {
            XCTFail("expected NetworkError.statusCode(401, _); threw \(error)")
            return
        }
        XCTAssertEqual(status, 401)
        XCTAssertEqual(error.toLoyaltyCardError(), permissionDenied())
    }

    private func assertLoyalty(
        _ expected: LoyaltyCardError,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("expected \(expected); the call was accepted")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, expected)
        } catch is CancellationError {
            XCTFail("expected \(expected); the call was cancelled")
        } catch {
            XCTFail("expected \(expected); threw \(error)")
        }
    }
}

private func permissionDenied() -> LoyaltyCardError {
    .underlying(.database(
        domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
        code: LoyaltyCardError.Underlying.firebasePermissionDeniedCode
    ))
}

private struct DiscardedBody: Decodable {}

private struct LoyaltySession {
    let subject: String
    let repository: HttpLoyaltyCardRepository
}

private func outcome<T>(_ body: () async throws -> T) async -> Result<T, Error> {
    do {
        return .success(try await body())
    } catch {
        return .failure(error)
    }
}

private func loyaltyErrors(in results: [Result<LoyaltyCardData, Error>]) -> [LoyaltyCardError] {
    results.compactMap { result in
        guard case .failure(let error) = result else { return nil }
        return error as? LoyaltyCardError
    }
}

private func describe(_ results: [Result<LoyaltyCardData, Error>]) -> String {
    results.map { result in
        switch result {
        case .success(let card):
            let points = card.points.map(String.init) ?? "nil"
            return "ok code=\(card.code) points=\(points) owner=\(card.ownerUserId ?? "nil")"
        case .failure(let error):
            return "error \(error)"
        }
    }.joined(separator: "; ")
}
