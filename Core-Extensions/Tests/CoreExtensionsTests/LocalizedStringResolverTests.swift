import XCTest
@testable import CoreExtensions

final class LocalizedStringResolverTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalizedStringResolverTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    /// Builds a throwaway bundle directory containing one `<language>.lproj/Localizable.strings`
    /// per entry in `languages`, mirroring how the app's real feature bundles are laid out.
    private func makeBundle(languages: [String: [String: String]]) throws -> Bundle {
        for (language, entries) in languages {
            let lprojURL = tempDirectory.appendingPathComponent("\(language).lproj", isDirectory: true)
            try FileManager.default.createDirectory(at: lprojURL, withIntermediateDirectories: true)
            let contents = entries
                .map { key, value in "\"\(key)\" = \"\(value)\";" }
                .joined(separator: "\n")
            try contents.write(
                to: lprojURL.appendingPathComponent("Localizable.strings"),
                atomically: true,
                encoding: .utf8
            )
        }
        let bundle = try XCTUnwrap(Bundle(url: tempDirectory), "Failed to load test bundle at \(tempDirectory!)")
        return bundle
    }

    func testResolvesStringFromExplicitLocaleRegardlessOfSystemLanguage() throws {
        let bundle = try makeBundle(languages: [
            "en": ["greeting": "Hello"],
            "hu": ["greeting": "Szia"]
        ])

        // This is the resolver's entire reason for existing: an explicit `hu` locale must win
        // even though the host process/simulator's own system language is English.
        let result = LocalizedStringResolver.string("greeting", locale: Locale(identifier: "hu"), bundle: bundle)

        XCTAssertEqual(result, "Szia")
    }

    func testDefaultsToEnglishWhenLocaleHasNoResolvableLanguageCode() throws {
        let bundle = try makeBundle(languages: [
            "en": ["greeting": "Hello"]
        ])

        // "und" (undetermined) is the one BCP-47 tag guaranteed to produce a nil languageCode.
        let result = LocalizedStringResolver.string("greeting", locale: Locale(identifier: "und"), bundle: bundle)

        XCTAssertEqual(result, "Hello")
    }

    func testReturnsKeyWhenKeyIsMissingFromTheResolvedLanguageBundle() throws {
        let bundle = try makeBundle(languages: [
            "en": ["greeting": "Hello"]
        ])

        let result = LocalizedStringResolver.string("missing.key", locale: Locale(identifier: "en"), bundle: bundle)

        XCTAssertEqual(result, "missing.key")
    }

    func testFallsBackToBaseBundleNegotiationWhenRequestedLanguageLprojIsMissing() throws {
        let bundle = try makeBundle(languages: [
            "en": ["greeting": "Hello"]
        ])

        // No "sk.lproj" exists, so the resolver falls back to the base bundle's own
        // (system-negotiated) lookup rather than crashing or force-unwrapping — compare against
        // that same call directly instead of hardcoding an expectation, since the negotiated
        // result legitimately depends on the host's preferred languages.
        let expected = bundle.localizedString(forKey: "greeting", value: nil, table: nil)
        let result = LocalizedStringResolver.string("greeting", locale: Locale(identifier: "sk"), bundle: bundle)

        XCTAssertEqual(result, expected)
    }
}
