import XCTest
@testable import minit

final class SettingsVersionPreferenceTests: XCTestCase {
    func testValueUsesMarketingVersionAndBuild() {
        XCTAssertEqual(
            SettingsVersionPreference.value(marketingVersion: "0.2", buildNumber: "9"),
            "0.2 (9)"
        )
        XCTAssertEqual(
            SettingsVersionPreference.value(marketingVersion: " 0.2 ", buildNumber: " 13 "),
            "0.2 (13)"
        )
    }

    func testMissingBuildDropsTheParentheses() {
        XCTAssertEqual(
            SettingsVersionPreference.value(marketingVersion: "0.2", buildNumber: " "),
            "0.2"
        )
    }

    func testMissingMarketingVersionIsEmpty() {
        XCTAssertEqual(
            SettingsVersionPreference.value(marketingVersion: " ", buildNumber: "9"),
            ""
        )
    }

    func testWriteStoresTheFormattedValue() {
        let suite = "saleseverest.minit.tests.settingsVersion"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suite)
        }

        SettingsVersionPreference.write(
            marketingVersion: "0.2",
            buildNumber: "9",
            defaults: defaults
        )

        XCTAssertEqual(defaults.string(forKey: SettingsVersionPreference.defaultsKey), "0.2 (9)")
    }

    func testWriteReadsTheHostBundleVersion() {
        let marketing = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let expected = SettingsVersionPreference.value(marketingVersion: marketing, buildNumber: build)
        XCTAssertFalse(expected.isEmpty)
        XCTAssertTrue(expected.hasPrefix(marketing.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
}
