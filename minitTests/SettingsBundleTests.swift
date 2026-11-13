import XCTest
@testable import minit

final class SettingsBundleTests: XCTestCase {
    func testPreferredLanguagesAreDeclaredOnTheApp() throws {
        let localizations = try XCTUnwrap(
            Bundle.main.object(forInfoDictionaryKey: "CFBundleLocalizations") as? [String]
        )
        XCTAssertEqual(Set(localizations), Set(["en", "sk", "hu"]))
    }

    func testSettingsBundleHasOnlyTheVersionRow() throws {
        let root = try rootPlist()
        let specifiers = try XCTUnwrap(root["PreferenceSpecifiers"] as? [[String: Any]])
        XCTAssertEqual(specifiers.count, 1)
        let row = try XCTUnwrap(specifiers.first)
        XCTAssertEqual(row["Type"] as? String, "PSTitleValueSpecifier")
        XCTAssertEqual(row["Title"] as? String, "Version")
        XCTAssertEqual(row["Key"] as? String, SettingsVersionPreference.defaultsKey)
    }

    func testVersionTitleIsLocalized() throws {
        XCTAssertEqual(try versionTitle(in: "en"), "Version")
        XCTAssertEqual(try versionTitle(in: "sk"), "Verzia")
        XCTAssertEqual(try versionTitle(in: "hu"), "Verzió")
    }

    private func settingsBundle() throws -> Bundle {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "Settings", withExtension: "bundle"),
            "Settings.bundle is missing from the app"
        )
        return try XCTUnwrap(Bundle(url: url))
    }

    private func rootPlist() throws -> [String: Any] {
        let url = try XCTUnwrap(settingsBundle().url(forResource: "Root", withExtension: "plist"))
        return try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: Any])
    }

    private func versionTitle(in language: String) throws -> String {
        let url = try XCTUnwrap(
            settingsBundle().url(forResource: "Root", withExtension: "strings", subdirectory: "\(language).lproj")
        )
        let strings = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        return try XCTUnwrap(strings["Version"])
    }
}
