import CoreNetworkingTestUtilities
import XCTest
@testable import DataLoyaltyCard
@testable import DataProfile

/// HTTP contract for `HttpProfileRepository`.
///
/// Skipped unless `MINIT_HTTP_CONTRACT` is `1`. Uses the same contract client
/// and the same hand-built JWT as the loyalty contract. `updateName` leaves
/// the linked card in place. This class imports neither FirebaseAuth nor
/// FirebaseDatabase.
final class HttpProfileContractTests: XCTestCase {
    override func setUp() async throws {
        try XCTSkipUnless(
            HttpContract.isEnabled,
            "HTTP contract is opt-in. Set MINIT_HTTP_CONTRACT=1 to call http://127.0.0.1:8080."
        )
        try await ContractHTTPClient(subject: "profile-reset").reset()
    }

    func testUpdateNameLeavesTheLinkedCardInPlace() async throws {
        let subject = "profile-update-name"
        let client = ContractHTTPClient(subject: subject)
        let loyalty = HttpLoyaltyCardRepository(client: client)
        let profile = HttpProfileRepository(client: client)

        let card = try await loyalty.createCard(userId: subject)
        XCTAssertEqual(card.points, 3210)
        XCTAssertEqual(card.ownerUserId, subject)

        try await profile.saveProfile(
            userId: subject,
            name: "Ada",
            surname: "Lovelace",
            email: "ada@example.com"
        )
        let saved = try await profile.fetchProfile(userId: subject)
        XCTAssertEqual(saved?.name, "Ada")
        XCTAssertEqual(saved?.surname, "Lovelace")
        XCTAssertEqual(saved?.email, "ada@example.com")

        try await profile.updateName(userId: subject, name: "Augusta")

        let updated = try await profile.fetchProfile(userId: subject)
        XCTAssertEqual(updated?.name, "Augusta")
        XCTAssertEqual(updated?.surname, "Lovelace")
        XCTAssertEqual(updated?.email, "ada@example.com")
        // Default public base URL matches HttpContract.baseURL when MINIT_PUBLIC_BASE_URL is unset.
        let avatarURL = try XCTUnwrap(updated?.avatarUrl)
        XCTAssertEqual(avatarURL, HttpContract.baseURL + "/v1/media/avatars/default.webp")
        XCTAssertTrue(avatarURL.hasSuffix("/v1/media/avatars/default.webp"))
        let linked = try await loyalty.fetchLinkedCard(userId: subject)
        XCTAssertEqual(linked, card)
    }
}
