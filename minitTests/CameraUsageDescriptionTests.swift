import XCTest

final class CameraUsageDescriptionTests: XCTestCase {
    private let purposeKey = "NSCameraUsageDescription"
    private let english = "Minit needs camera access to scan your loyalty card QR code."
    private let hungarian = "A Minitnek hozzáférésre van szüksége a kamerához a hűségkártyád QR-kódjának beolvasásához."
    private let slovak = "Minit potrebuje prístup ku kamere na naskenovanie QR kódu vašej vernostnej karty."

    func testEnglishPurposeStringStaysTheDevelopmentValue() throws {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: purposeKey) as? String,
            english
        )
        XCTAssertEqual(try localizedPurpose(language: "en"), english)
    }

    func testHungarianAndSlovakPurposeStringsAreInTheAppBundle() throws {
        XCTAssertEqual(try localizedPurpose(language: "hu"), hungarian)
        XCTAssertEqual(try localizedPurpose(language: "sk"), slovak)
    }

    func testSentenceKeyedPurposeEntryIsAbsent() throws {
        for language in ["en", "hu", "sk"] {
            let strings = try infoPlistStrings(language: language)
            XCTAssertNil(
                strings[english],
                "Dead camera sentence key is still in \(language).lproj/InfoPlist.strings"
            )
            XCTAssertNotNil(strings[purposeKey])
        }
    }

    private func localizedPurpose(language: String) throws -> String {
        try XCTUnwrap(
            try infoPlistStrings(language: language)[purposeKey],
            "Missing \(purposeKey) in \(language).lproj/InfoPlist.strings"
        )
    }

    private func infoPlistStrings(language: String) throws -> [String: String] {
        let lproj = try XCTUnwrap(
            Bundle.main.url(forResource: language, withExtension: "lproj"),
            "Missing \(language).lproj"
        )
        let url = lproj.appendingPathComponent("InfoPlist.strings")
        return try XCTUnwrap(
            NSDictionary(contentsOf: url) as? [String: String],
            "Missing or unreadable \(language).lproj/InfoPlist.strings"
        )
    }
}
