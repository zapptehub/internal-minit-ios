import XCTest
@testable import DataLoyaltyCard

final class LoyaltyCardModelsTests: XCTestCase {
    func testLoyaltyCardData_defaultsOptionalFieldsToNil() {
        let card = LoyaltyCardData(code: "TEST-001")

        XCTAssertEqual(card.code, "TEST-001")
        XCTAssertNil(card.ownerUserId)
        XCTAssertNil(card.points)
    }

    func testLoyaltyCardDto_roundTripsToModel() {
        let dto = LoyaltyCardDto(code: "C1", ownerUserId: "u1", points: 10)
        XCTAssertEqual(dto.toModel(), LoyaltyCardData(code: "C1", ownerUserId: "u1", points: 10))
        XCTAssertEqual(dto.toModel().toDto(), dto)
    }

    func testLoyaltyCardError_equatableCases() {
        XCTAssertEqual(LoyaltyCardError.notFound, .notFound)
        XCTAssertEqual(LoyaltyCardError.alreadyClaimed, .alreadyClaimed)
        XCTAssertEqual(LoyaltyCardError.alreadyLinked, .alreadyLinked)
        XCTAssertEqual(
            LoyaltyCardError.underlying("x"),
            LoyaltyCardError.underlying("x")
        )
        XCTAssertNotEqual(
            LoyaltyCardError.underlying("x"),
            LoyaltyCardError.underlying("y")
        )
    }
}

final class LoyaltyCardRepositoryTests: XCTestCase {
    func testCreateCard_isIdempotentForSameUser() async throws {
        let api = InMemoryLoyaltyCardApi()
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let first = try await repository.createCard(userId: "u1")
        let second = try await repository.createCard(userId: "u1")

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.ownerUserId, "u1")
        XCTAssertEqual(first.points, LoyaltyCardRepositoryImpl.defaultNewCardPoints)
        XCTAssertEqual(api.linkedCardIds["u1"], first.code)
        XCTAssertEqual(api.cards.count, 1)
    }

    func testCreateCard_concurrentWritersShareOneLinkedCard() async throws {
        let api = InMemoryLoyaltyCardApi()
        // Pre-link a winner so the second create observes the existing id.
        api.linkedCardIds["u1"] = "MINIT-EXISTING"
        api.cards["MINIT-EXISTING"] = LoyaltyCardDto(
            code: "MINIT-EXISTING",
            ownerUserId: "u1",
            points: 0
        )
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.createCard(userId: "u1")

        XCTAssertEqual(card.code, "MINIT-EXISTING")
        XCTAssertEqual(api.cards.count, 1)
    }

    func testClaimCard_claimsUnclaimedSeedAndLinksUser() async throws {
        let api = InMemoryLoyaltyCardApi()
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: nil, points: 100)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.claimCard(userId: "u1", code: "  SEED-001  ")

        XCTAssertEqual(card.code, "SEED-001")
        XCTAssertEqual(card.ownerUserId, "u1")
        XCTAssertEqual(card.points, 100)
        XCTAssertEqual(api.linkedCardIds["u1"], "SEED-001")
    }

    func testClaimCard_isIdempotentWhenAlreadyLinkedToSameCard() async throws {
        let api = InMemoryLoyaltyCardApi()
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: "u1", points: 5)
        api.linkedCardIds["u1"] = "SEED-001"
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.claimCard(userId: "u1", code: "SEED-001")

        XCTAssertEqual(card.code, "SEED-001")
        XCTAssertEqual(api.cards.count, 1)
    }

    func testClaimCard_throwsNotFoundForUnknownCode() async {
        let repository = LoyaltyCardRepositoryImpl(api: InMemoryLoyaltyCardApi())

        do {
            _ = try await repository.claimCard(userId: "u1", code: "MISSING")
            XCTFail("Expected notFound")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClaimCard_throwsAlreadyClaimedWhenOwnedByAnotherUser() async {
        let api = InMemoryLoyaltyCardApi()
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: "other", points: 0)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        do {
            _ = try await repository.claimCard(userId: "u1", code: "SEED-001")
            XCTFail("Expected alreadyClaimed")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .alreadyClaimed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testClaimCard_throwsAlreadyLinkedWhenUserHasDifferentCard() async {
        let api = InMemoryLoyaltyCardApi()
        api.linkedCardIds["u1"] = "OWN-CARD"
        api.cards["OWN-CARD"] = LoyaltyCardDto(code: "OWN-CARD", ownerUserId: "u1", points: 0)
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: nil, points: 0)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        do {
            _ = try await repository.claimCard(userId: "u1", code: "SEED-001")
            XCTFail("Expected alreadyLinked")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .alreadyLinked)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchLinkedCard_returnsNilWhenUnlinked() async throws {
        let repository = LoyaltyCardRepositoryImpl(api: InMemoryLoyaltyCardApi())
        let card = try await repository.fetchLinkedCard(userId: "u1")
        XCTAssertNil(card)
    }

    func testFetchLinkedCard_returnsCardWhenLinked() async throws {
        let api = InMemoryLoyaltyCardApi()
        api.linkedCardIds["u1"] = "C1"
        api.cards["C1"] = LoyaltyCardDto(code: "C1", ownerUserId: "u1", points: 42)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.fetchLinkedCard(userId: "u1")

        XCTAssertEqual(card, LoyaltyCardData(code: "C1", ownerUserId: "u1", points: 42))
    }

    func testClaimCard_throwsNotFoundForBlankCode() async {
        let repository = LoyaltyCardRepositoryImpl(api: InMemoryLoyaltyCardApi())

        do {
            _ = try await repository.claimCard(userId: "u1", code: "   ")
            XCTFail("Expected notFound")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

/// Test double that mirrors the Firebase transaction semantics used by
/// `FirebaseLoyaltyCardApiImpl` without requiring a live backend.
private final class InMemoryLoyaltyCardApi: LoyaltyCardApi, @unchecked Sendable {
    var linkedCardIds: [String: String] = [:]
    var cards: [String: LoyaltyCardDto] = [:]

    func fetchLinkedCardId(userId: String) async throws -> String? {
        linkedCardIds[userId]
    }

    func linkCardIdIfAbsent(userId: String, code: String) async throws -> String {
        if let existing = linkedCardIds[userId], !existing.isEmpty {
            return existing
        }
        linkedCardIds[userId] = code
        return code
    }

    func fetchCard(code: String) async throws -> LoyaltyCardDto? {
        cards[code]
    }

    func ensureCardOwned(code: String, ownerUserId: String, points: Int) async throws -> LoyaltyCardDto {
        if let existing = cards[code] {
            if let owner = existing.ownerUserId, owner != ownerUserId {
                throw LoyaltyCardError.alreadyClaimed
            }
            let updated = LoyaltyCardDto(
                code: code,
                ownerUserId: ownerUserId,
                points: existing.points ?? points
            )
            cards[code] = updated
            return updated
        }

        let created = LoyaltyCardDto(code: code, ownerUserId: ownerUserId, points: points)
        cards[code] = created
        return created
    }

    func claimExistingCard(code: String, userId: String) async throws -> LoyaltyCardDto {
        guard let existing = cards[code] else {
            throw LoyaltyCardError.notFound
        }
        if let owner = existing.ownerUserId, owner != userId {
            throw LoyaltyCardError.alreadyClaimed
        }
        let claimed = LoyaltyCardDto(code: code, ownerUserId: userId, points: existing.points)
        cards[code] = claimed
        return claimed
    }
}
