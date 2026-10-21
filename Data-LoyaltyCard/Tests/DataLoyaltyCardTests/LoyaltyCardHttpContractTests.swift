import CoreNetworking
import CoreNetworkingTestUtilities
import Foundation
import XCTest
@testable import DataLoyaltyCard

final class LoyaltyCardHttpContractTests: XCTestCase {
    func testLoyaltyCardFixtureDecodes3210SilverAndAlreadyRegisteredIsAlreadyClaimed() throws {
        let card = try JSONDecoder().decode(
            LoyaltyCardResponse.self,
            from: ContractFixtures.bytes("loyalty-card.json")
        )
        XCTAssertEqual(card.code, "MINIT-CONTRACT1")
        XCTAssertEqual(card.points, 3210)
        XCTAssertEqual(card.tierId, "silver")

        let model = card.toModel(ownerUserId: "user-1")
        XCTAssertEqual(
            model,
            LoyaltyCardData(code: "MINIT-CONTRACT1", ownerUserId: "user-1", points: 3210)
        )

        let withOwner = Data(
            #"{"code":"MINIT-CONTRACT1","points":3210,"tierId":"silver","ownerUserId":"other"}"#.utf8
        )
        let decodedOwner = try JSONDecoder().decode(LoyaltyCardResponse.self, from: withOwner)
        XCTAssertEqual(decodedOwner.toModel(ownerUserId: "user-1").ownerUserId, "user-1")

        let mapped = NetworkError
            .statusCode(409, try ContractFixtures.bytes("already-registered.json"))
            .toLoyaltyCardError()
        XCTAssertEqual(mapped, .alreadyClaimed)
    }

    func testLookupFixturesAreCodeAndStatusOnly() throws {
        let cases = [
            ("lookup-available.json", "MINIT-AVAIL0001", "available"),
            ("lookup-yours.json", "MINIT-CONTRACT1", "yours"),
            ("lookup-registered.json", "MINIT-OTHER0001", "registered"),
        ]
        for (name, code, status) in cases {
            let lookup = try JSONDecoder().decode(
                LoyaltyCardLookupResponse.self,
                from: ContractFixtures.bytes(name)
            )
            XCTAssertEqual(lookup, LoyaltyCardLookupResponse(code: code, status: status), name)
        }

        let extraOwner = Data(
            #"{"code":"MINIT-OTHER0001","status":"registered","ownerUserId":"other-user"}"#.utf8
        )
        let registered = try JSONDecoder().decode(LoyaltyCardLookupResponse.self, from: extraOwner)
        XCTAssertEqual(
            registered,
            LoyaltyCardLookupResponse(code: "MINIT-OTHER0001", status: "registered")
        )
    }

    func testPointsHistoryFixturesDecodeCursorsAndReasonStrings() throws {
        let first = try JSONDecoder().decode(
            PointsHistoryResponse.self,
            from: ContractFixtures.bytes("points-history.json")
        ).toModel()
        let item = try XCTUnwrap(first.items.first)
        XCTAssertEqual(first.items.count, 1)
        XCTAssertEqual(item.id, "00000000-0000-4000-8000-000000000001")
        XCTAssertEqual(item.delta, 3210)
        XCTAssertEqual(item.balanceAfter, 3210)
        XCTAssertEqual(item.reasonKey, "initial_grant")
        XCTAssertEqual(item.reason.en, "Starting balance")
        XCTAssertEqual(item.reason.sk, "Počiatočný zostatok")
        XCTAssertEqual(item.reason.hu, "Kezdő egyenleg")
        XCTAssertEqual(item.createdAt, "2026-10-17T07:25:00.000000Z")
        XCTAssertNil(first.nextCursor)

        let page = try JSONDecoder().decode(
            PointsHistoryResponse.self,
            from: ContractFixtures.bytes("points-history-page.json")
        ).toModel()
        XCTAssertEqual(
            page.nextCursor,
            "MjAyNC0wNi0wMVQwMDowMDowMC4wMDAwMDFafDAwMDAwMDAwLTAwMDAtNDAwMC04MDAwLTAwMDAwMDAwMDAwMg"
        )
        XCTAssertEqual(page.items.first?.balanceAfter, 3220)
    }

    /// Moved from the 4.5 fixture suite. `bad-request.json` is `.underlying(.decoding)`.
    /// `unauthenticated.json` is permission denied: the status the client returns
    /// after its single refresh is exhausted.
    func testBadRequestFixtureIsDecodingAndUnauthenticatedIsPermissionDenied() throws {
        let badRequest = NetworkError
            .statusCode(400, try ContractFixtures.bytes("bad-request.json"))
            .toLoyaltyCardError()
        XCTAssertEqual(badRequest, .underlying(.decoding))

        let unauthenticated = NetworkError
            .statusCode(401, try ContractFixtures.bytes("unauthenticated.json"))
            .toLoyaltyCardError()
        XCTAssertEqual(unauthenticated, permissionDenied())
    }

    func testHttpStatusesMapOntoLoyaltyCardError() throws {
        let alreadyLinked = try status(409, "already-linked.json").toLoyaltyCardError()
        XCTAssertEqual(alreadyLinked, .alreadyLinked)
        let notFound = try status(404, "not-found.json").toLoyaltyCardError()
        XCTAssertEqual(notFound, .notFound)
        let invalidCode = try status(400, "invalid-code.json").toLoyaltyCardError()
        XCTAssertEqual(invalidCode, .notFound)
        let invalidData = try status(400, "invalid-data.json").toLoyaltyCardError()
        XCTAssertEqual(invalidData, .underlying(.decoding))
        let badRequest = try status(400, "bad-request.json").toLoyaltyCardError()
        XCTAssertEqual(badRequest, .underlying(.decoding))
        let unauthenticated = try status(401, "unauthenticated.json").toLoyaltyCardError()
        XCTAssertEqual(unauthenticated, permissionDenied())
        let forbidden = NetworkError
            .statusCode(403, try ContractFixtures.bytes("unauthenticated.json"))
            .toLoyaltyCardError()
        XCTAssertEqual(forbidden, permissionDenied())
        XCTAssertEqual(NetworkError.statusCode(502, Data()).toLoyaltyCardError(), unavailable())
        XCTAssertEqual(NetworkError.statusCode(503, Data()).toLoyaltyCardError(), unavailable())
        XCTAssertEqual(NetworkError.statusCode(504, Data()).toLoyaltyCardError(), unavailable())

        let methodNotAllowed = try status(405, "method-not-allowed.json").toLoyaltyCardError()
        XCTAssertEqual(methodNotAllowed, .underlying(.unknown))
        XCTAssertEqual(NetworkError.statusCode(429, Data()).toLoyaltyCardError(), .underlying(.unknown))
        let internalError = Data(#"{"error":{"code":"internal","message":"Internal server error"}}"#.utf8)
        XCTAssertEqual(NetworkError.statusCode(500, internalError).toLoyaltyCardError(), .underlying(.unknown))
        let otherConflict = Data(#"{"error":{"code":"other","message":"no"}}"#.utf8)
        XCTAssertEqual(NetworkError.statusCode(409, otherConflict).toLoyaltyCardError(), .underlying(.unknown))
        XCTAssertEqual(NetworkError.statusCode(404, Data()).toLoyaltyCardError(), .underlying(.unknown))
        XCTAssertFalse(NetworkError.statusCode(404, Data()).isLoyaltyNotFound())
        let missingCard = try status(404, "not-found.json")
        XCTAssertTrue(missingCard.isLoyaltyNotFound())

        XCTAssertEqual(
            NetworkError.unknown(URLError(.notConnectedToInternet)).toLoyaltyCardError(),
            .underlying(.unknown)
        )
        XCTAssertEqual(NetworkError.invalidURL.toLoyaltyCardError(), .underlying(.unknown))
        XCTAssertEqual(
            NetworkError.decodingFailed(SampleFailure()).toLoyaltyCardError(),
            .underlying(.decoding)
        )
        XCTAssertEqual(NetworkError.invalidResponse.toLoyaltyCardError(), .underlying(.decoding))
    }

    private func status(_ code: Int, _ fixture: String) throws -> NetworkError {
        NetworkError.statusCode(code, try ContractFixtures.bytes(fixture))
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
