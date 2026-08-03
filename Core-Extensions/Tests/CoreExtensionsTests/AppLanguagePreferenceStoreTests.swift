import XCTest
@testable import CoreExtensions

@MainActor
final class AppLanguagePreferenceStoreTests: XCTestCase {
    private let suiteName = "CoreExtensionsTests.AppLanguagePreferenceStoreTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testLanguageCodeIsNilWhenNoChoiceHasBeenMade() {
        let store = UserDefaultsAppLanguagePreferenceStore(userDefaults: defaults, key: "language")

        XCTAssertNil(store.languageCode)
    }

    func testSettingLanguageCodePersistsItThroughUserDefaults() {
        let store = UserDefaultsAppLanguagePreferenceStore(userDefaults: defaults, key: "language")

        store.languageCode = "hu"

        XCTAssertEqual(store.languageCode, "hu")
        XCTAssertEqual(defaults.string(forKey: "language"), "hu")
    }

    func testSettingLanguageCodeToNilClearsIt() {
        let store = UserDefaultsAppLanguagePreferenceStore(userDefaults: defaults, key: "language")
        store.languageCode = "sk"

        store.languageCode = nil

        XCTAssertNil(store.languageCode)
    }

    func testTwoStoresSharingTheSameKeyAndDefaultsObserveEachOthersWrites() {
        let writer = UserDefaultsAppLanguagePreferenceStore(userDefaults: defaults, key: "language")
        let reader = UserDefaultsAppLanguagePreferenceStore(userDefaults: defaults, key: "language")

        writer.languageCode = "en"

        XCTAssertEqual(reader.languageCode, "en")
    }

    func testDefaultKeyMatchesExpectedConstant() {
        XCTAssertEqual(UserDefaultsAppLanguagePreferenceStore.defaultKey, "minit.app.language")
    }
}
