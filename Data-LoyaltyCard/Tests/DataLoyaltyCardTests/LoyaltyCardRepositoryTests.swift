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
            LoyaltyCardError.underlying(.unknown),
            LoyaltyCardError.underlying(.unknown)
        )
        XCTAssertEqual(
            LoyaltyCardError.underlying(.database(domain: "com.firebase", code: 1)),
            LoyaltyCardError.underlying(.database(domain: "com.firebase", code: 1))
        )
        XCTAssertNotEqual(
            LoyaltyCardError.underlying(.unknown),
            LoyaltyCardError.underlying(.decoding)
        )
        XCTAssertNotEqual(
            LoyaltyCardError.underlying(.database(domain: "com.firebase", code: 1)),
            LoyaltyCardError.underlying(.database(domain: "com.firebase", code: 2))
        )
    }

    func testCodeNormalization_trimsKotlinWhitespaceWithoutChangingCase() {
        XCTAssertEqual("  Seed-aB1\n".normalizeLoyaltyCardCode(), "Seed-aB1")
        XCTAssertEqual("\u{00A0}Seed-aB1\u{00A0}".normalizeLoyaltyCardCode(), "Seed-aB1")
        XCTAssertEqual("\u{001C}Seed-aB1\u{001F}".normalizeLoyaltyCardCode(), "Seed-aB1")
        XCTAssertEqual("\u{2028}Seed-aB1\u{2029}".normalizeLoyaltyCardCode(), "Seed-aB1")
        XCTAssertEqual("\u{0085}Seed-aB1".normalizeLoyaltyCardCode(), "\u{0085}Seed-aB1")
        XCTAssertEqual("\u{007F}SEED\u{007F}".normalizeLoyaltyCardCode(), "\u{007F}SEED\u{007F}")
        XCTAssertEqual("\u{0000}SEED".normalizeLoyaltyCardCode(), "\u{0000}SEED")
        XCTAssertEqual("   ".normalizeLoyaltyCardCode(), "")
        XCTAssertEqual("\n\t".normalizeLoyaltyCardCode(), "")
    }

    func testIsValidLoyaltyCardCode_matchesAndroidKeyRules() {
        XCTAssertTrue("SEED-001".isValidLoyaltyCardCode())
        XCTAssertTrue("Seed aB1".isValidLoyaltyCardCode())
        XCTAssertTrue(" ".isValidLoyaltyCardCode())
        XCTAssertTrue("\u{0085}Seed-aB1".isValidLoyaltyCardCode())
        XCTAssertTrue(String(repeating: "A", count: 800).isValidLoyaltyCardCode())

        XCTAssertFalse("".isValidLoyaltyCardCode())
        XCTAssertFalse("   ".normalizeLoyaltyCardCode().isValidLoyaltyCardCode())
        XCTAssertFalse("\n".isValidLoyaltyCardCode())

        for character in [".", "#", "$", "[", "]", "/"] {
            XCTAssertFalse(
                "SEED\(character)001".isValidLoyaltyCardCode(),
                "Expected \(character) to be rejected"
            )
        }

        for value in Array(0...31) + [127] {
            let scalar = Unicode.Scalar(value)!
            let code = "SEED\(Character(scalar))001"
            XCTAssertFalse(
                code.isValidLoyaltyCardCode(),
                "Expected U+\(String(value, radix: 16, uppercase: true)) to be rejected"
            )
        }
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
        XCTAssertEqual(api.claimCalls, 0)
        XCTAssertEqual(api.claimAndLinkCalls, 1)
    }

    func testClaimCard_isIdempotentWhenAlreadyLinkedToSameCard() async throws {
        let api = InMemoryLoyaltyCardApi()
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: "u1", points: 5)
        api.linkedCardIds["u1"] = "SEED-001"
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.claimCard(userId: "u1", code: "SEED-001")

        XCTAssertEqual(card.code, "SEED-001")
        XCTAssertEqual(api.cards.count, 1)
        XCTAssertEqual(api.claimCalls, 0)
        XCTAssertEqual(api.claimAndLinkCalls, 0)
    }

    func testClaimCard_claimsUnownedRecordBehindMatchingLink() async throws {
        let api = InMemoryLoyaltyCardApi()
        api.linkedCardIds["u1"] = "SEED-001"
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: nil, points: 5)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.claimCard(userId: "u1", code: "SEED-001")

        XCTAssertEqual(card.ownerUserId, "u1")
        XCTAssertEqual(card.points, 5)
        XCTAssertEqual(api.claimCalls, 0)
        XCTAssertEqual(api.claimAndLinkCalls, 1)
    }

    func testClaimCard_foreignOwnerBehindSameCodeFallsThroughToAlreadyClaimed() async {
        let api = InMemoryLoyaltyCardApi()
        api.linkedCardIds["u1"] = "SEED-001"
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: "other", points: 5)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        do {
            _ = try await repository.claimCard(userId: "u1", code: "SEED-001")
            XCTFail("Expected alreadyClaimed")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .alreadyClaimed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(api.claimAndLinkCalls, 1)
        XCTAssertEqual(api.cards["SEED-001"]?.ownerUserId, "other")
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

        XCTAssertNil(api.cards["SEED-001"]?.ownerUserId)
        XCTAssertEqual(api.claimAndLinkCalls, 0)
    }

    func testClaimCard_leavesSeedUnownedWhenAnotherWriterWinsTheLink() async {
        let api = InMemoryLoyaltyCardApi()
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: nil, points: 9)
        api.linkResultOverride = "MINIT-OTHER"
        let repository = LoyaltyCardRepositoryImpl(api: api)

        do {
            _ = try await repository.claimCard(userId: "u1", code: "SEED-001")
            XCTFail("Expected alreadyLinked")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .alreadyLinked)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertNil(api.cards["SEED-001"]?.ownerUserId)
        XCTAssertNil(api.linkedCardIds["u1"])
        XCTAssertEqual(api.claimCalls, 0)
        XCTAssertEqual(api.claimAndLinkCalls, 1)
    }

    func testClaimCard_linksACardThisUserAlreadyOwns() async throws {
        let api = InMemoryLoyaltyCardApi()
        api.cards["SEED-001"] = LoyaltyCardDto(code: "SEED-001", ownerUserId: "u1", points: 5)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.claimCard(userId: "u1", code: "SEED-001")

        XCTAssertEqual(card, LoyaltyCardData(code: "SEED-001", ownerUserId: "u1", points: 5))
        XCTAssertEqual(api.linkedCardIds["u1"], "SEED-001")
        XCTAssertEqual(api.cards.count, 1)
        XCTAssertEqual(api.claimAndLinkCalls, 1)
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

    func testFetchLinkedCard_hidesCardOwnedByAnotherUser() async throws {
        let api = InMemoryLoyaltyCardApi()
        api.linkedCardIds["u1"] = "C1"
        api.cards["C1"] = LoyaltyCardDto(code: "C1", ownerUserId: "other-user", points: 42)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.fetchLinkedCard(userId: "u1")

        XCTAssertNil(card)
        XCTAssertEqual(api.fetchCardCalls, 1)
    }

    func testCreateCard_doesNotReturnAForeignOwnedCardBehindAnExistingLink() async {
        let api = InMemoryLoyaltyCardApi()
        api.linkedCardIds["u1"] = "MINIT-FOREIGN"
        api.cards["MINIT-FOREIGN"] = LoyaltyCardDto(
            code: "MINIT-FOREIGN",
            ownerUserId: "other-user",
            points: 50
        )
        let repository = LoyaltyCardRepositoryImpl(api: api)

        do {
            _ = try await repository.createCard(userId: "u1")
            XCTFail("Expected alreadyClaimed")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .alreadyClaimed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(api.cards["MINIT-FOREIGN"]?.ownerUserId, "other-user")
        XCTAssertEqual(api.ensureCardOwnedCalls, 1)
    }

    func testClaimCard_throwsNotFoundForBlankCode() async {
        let api = InMemoryLoyaltyCardApi()
        let repository = LoyaltyCardRepositoryImpl(api: api)

        do {
            _ = try await repository.claimCard(userId: "u1", code: "   ")
            XCTFail("Expected notFound")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(api.fetchLinkedCardIdCalls, 0)
        XCTAssertEqual(api.fetchCardCalls, 0)
        XCTAssertEqual(api.claimCalls, 0)
        XCTAssertEqual(api.claimAndLinkCalls, 0)
    }

    func testClaimCard_trimsKotlinWhitespaceThenClaims() async throws {
        let api = InMemoryLoyaltyCardApi()
        api.cards["Seed-aB1"] = LoyaltyCardDto(code: "Seed-aB1", ownerUserId: nil, points: 4)
        let repository = LoyaltyCardRepositoryImpl(api: api)

        let card = try await repository.claimCard(userId: "u1", code: "\u{001C}  Seed-aB1\n\u{001F}")

        XCTAssertEqual(card.code, "Seed-aB1")
        XCTAssertEqual(card.ownerUserId, "u1")
        XCTAssertEqual(api.claimAndLinkCalls, 1)
    }

    func testClaimCard_rejectsFirebaseInvalidCodesBeforeReachingTheApi() async {
        var samples = ["", "   ", "\n", "\t", "\u{001C}", "\u{007F}SEED\u{007F}"]
        for character in [".", "#", "$", "[", "]", "/"] {
            samples.append("SEED\(character)001")
        }
        // Interior controls stay after trim. U+0009–U+000D and U+001C–U+001F
        // at either end are whitespace and would be removed first.
        for value in Array(0...31) + [127] {
            let scalar = Unicode.Scalar(value)!
            samples.append("SEED\(Character(scalar))001")
        }

        for code in samples {
            let api = InMemoryLoyaltyCardApi()
            api.cards[code] = LoyaltyCardDto(code: code, ownerUserId: nil, points: 1)
            let repository = LoyaltyCardRepositoryImpl(api: api)

            do {
                _ = try await repository.claimCard(userId: "u1", code: code)
                XCTFail("Expected notFound for \(code.debugDescription)")
            } catch let error as LoyaltyCardError {
                XCTAssertEqual(error, .notFound, code.debugDescription)
            } catch {
                XCTFail("Unexpected error for \(code.debugDescription): \(error)")
            }

            XCTAssertEqual(api.fetchLinkedCardIdCalls, 0, code.debugDescription)
            XCTAssertEqual(api.fetchCardCalls, 0, code.debugDescription)
            XCTAssertEqual(api.claimCalls, 0, code.debugDescription)
            XCTAssertEqual(api.claimAndLinkCalls, 0, code.debugDescription)
            XCTAssertNil(api.cards[code]?.ownerUserId, code.debugDescription)
        }
    }

    func testCreateCard_rejectsInvalidLinkedCodeBeforeCardPath() async {
        let api = InMemoryLoyaltyCardApi()
        api.linkedCardIds["u1"] = "MINIT/INVALID"
        let repository = LoyaltyCardRepositoryImpl(api: api)

        do {
            _ = try await repository.createCard(userId: "u1")
            XCTFail("Expected decoding")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .underlying(.decoding))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(api.fetchCardCalls, 0)
        XCTAssertEqual(api.ensureCardOwnedCalls, 0)
    }

    func testFetchLinkedCard_ignoresInvalidStoredKeyWithoutReadingCard() async throws {
        let storedKeys = ["C1/INVALID", "SEED.001", "SEED#001", "SEED$001", "SEED[001", "SEED]001", "\u{0000}", "\u{007F}", "\t"]
        for linkedId in storedKeys {
            let api = InMemoryLoyaltyCardApi()
            api.linkedCardIds["u1"] = linkedId
            api.cards[linkedId] = LoyaltyCardDto(code: linkedId, ownerUserId: "u1", points: 1)
            let repository = LoyaltyCardRepositoryImpl(api: api)

            let card = try await repository.fetchLinkedCard(userId: "u1")

            XCTAssertNil(card, linkedId.debugDescription)
            XCTAssertEqual(api.fetchCardCalls, 0, linkedId.debugDescription)
        }
    }
}

final class FirebaseLoyaltyCardCodeGuardTests: XCTestCase {
    func testApiRejectsInvalidCodesBeforeOpeningADatabasePath() async {
        let api = FirebaseLoyaltyCardApiImpl()
        let codes = Self.rejectedCodes

        for code in codes {
            await Self.assertNotFound(code.debugDescription) {
                _ = try await api.fetchCard(code: code)
            }
            await Self.assertNotFound(code.debugDescription) {
                _ = try await api.claimExistingCard(code: code, userId: "u1")
            }
            await Self.assertNotFound(code.debugDescription) {
                _ = try await api.claimAndLink(code: code, userId: "u1")
            }
            do {
                _ = try await api.ensureCardOwned(code: code, ownerUserId: "u1", points: 0)
                XCTFail("Expected decoding for \(code.debugDescription)")
            } catch let error as LoyaltyCardError {
                XCTAssertEqual(error, .underlying(.decoding), code.debugDescription)
            } catch {
                XCTFail("Unexpected error for \(code.debugDescription): \(error)")
            }
        }
    }

    private static let rejectedCodes: [String] = {
        var codes = ["", "SEED\u{0000}", "SEED\u{001F}", "SEED\u{007F}"]
        for character in [".", "#", "$", "[", "]", "/"] {
            codes.append("SEED\(character)001")
        }
        return codes
    }()

    private static func assertNotFound(
        _ message: String,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("Expected notFound for \(message)")
        } catch let error as LoyaltyCardError {
            XCTAssertEqual(error, .notFound, message)
        } catch {
            XCTFail("Unexpected error for \(message): \(error)")
        }
    }
}

/// Test double that mirrors the Firebase transaction semantics used by
/// `FirebaseLoyaltyCardApiImpl` without requiring a live backend.
private final class InMemoryLoyaltyCardApi: LoyaltyCardApi, @unchecked Sendable {
    var linkedCardIds: [String: String] = [:]
    var cards: [String: LoyaltyCardDto] = [:]
    var linkResultOverride: String?
    var fetchLinkedCardIdCalls = 0
    var fetchCardCalls = 0
    var ensureCardOwnedCalls = 0
    var claimCalls = 0
    var claimAndLinkCalls = 0

    func fetchLinkedCardId(userId: String) async throws -> String? {
        fetchLinkedCardIdCalls += 1
        return linkedCardIds[userId]
    }

    func linkCardIdIfAbsent(userId: String, code: String) async throws -> String {
        if let existing = linkedCardIds[userId], !existing.isEmpty {
            return existing
        }
        linkedCardIds[userId] = code
        return code
    }

    func fetchCard(code: String) async throws -> LoyaltyCardDto? {
        fetchCardCalls += 1
        return cards[code]
    }

    func ensureCardOwned(code: String, ownerUserId: String, points: Int) async throws -> LoyaltyCardDto {
        ensureCardOwnedCalls += 1
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
        claimCalls += 1
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

    func claimAndLink(code: String, userId: String) async throws -> LoyaltyCardDto {
        claimAndLinkCalls += 1
        if let winner = linkResultOverride, winner != code {
            throw LoyaltyCardError.alreadyLinked
        }
        if let existingLink = linkedCardIds[userId], !existingLink.isEmpty, existingLink != code {
            throw LoyaltyCardError.alreadyLinked
        }
        guard let existing = cards[code] else {
            throw LoyaltyCardError.notFound
        }
        if let owner = existing.ownerUserId, owner != userId {
            throw LoyaltyCardError.alreadyClaimed
        }
        linkedCardIds[userId] = code
        let claimed = LoyaltyCardDto(code: code, ownerUserId: userId, points: existing.points)
        cards[code] = claimed
        return claimed
    }
}
