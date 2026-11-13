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

    func testFakeThatDoesNotImplementFetchPointsHistoryReturnsAnEmptyPage() async throws {
        let repository: LoyaltyCardRepository = EmptyPointsHistoryRepository()

        let page = try await repository.fetchPointsHistory(limit: 1, cursor: nil)

        XCTAssertTrue(page.items.isEmpty)
        XCTAssertNil(page.nextCursor)
    }
}

/// Conforms without `fetchPointsHistory`, the same shape as the onboarding and
/// app-flow fakes.
private struct EmptyPointsHistoryRepository: LoyaltyCardRepository {
    func createCard(userId: String) async throws -> LoyaltyCardData {
        LoyaltyCardData(code: "unused", ownerUserId: userId)
    }

    func claimCard(userId: String, code: String) async throws -> LoyaltyCardData {
        LoyaltyCardData(code: code, ownerUserId: userId)
    }

    func fetchLinkedCard(userId _: String) async throws -> LoyaltyCardData? {
        nil
    }
}
