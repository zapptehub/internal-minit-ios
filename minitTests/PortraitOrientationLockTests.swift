import XCTest

/// Task 10.4 decision: the app is portrait only on iPhone and iPad, matching Android's
/// `android:screenOrientation="portrait"`. iPad needs full screen for a portrait-only app.
/// Reads the built Info.plist file directly, because `Bundle.infoDictionary` resolves
/// the `~iphone` / `~ipad` keys for the running device only.
final class PortraitOrientationLockTests: XCTestCase {
    private func rawInfoPlist() throws -> [String: Any] {
        let url = Bundle.main.bundleURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }

    func testIPhoneSupportsPortraitOnly() throws {
        XCTAssertEqual(
            try rawInfoPlist()["UISupportedInterfaceOrientations~iphone"] as? [String],
            ["UIInterfaceOrientationPortrait"]
        )
    }

    func testIPadSupportsPortraitOnlyAndRequiresFullScreen() throws {
        let plist = try rawInfoPlist()
        XCTAssertEqual(plist["UISupportedInterfaceOrientations~ipad"] as? [String], ["UIInterfaceOrientationPortrait"])
        XCTAssertEqual(plist["UIRequiresFullScreen"] as? Bool, true)
    }
}
