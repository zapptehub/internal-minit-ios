import XCTest
@testable import minit
import CoreExtensions

final class AppLanguageSettingsReconcilerTests: XCTestCase {
    func testSettingsLanguageReplacesTheStoredChoice() {
        let decision = AppLanguageSettingsLogic.decide(
            snapshot(stored: "hu", applied: "hu", apple: ["sk"])
        )

        XCTAssertEqual(decision.displayLanguageCode, "sk")
        XCTAssertEqual(decision.storedLanguageCode, "sk")
        XCTAssertEqual(decision.appliedLanguageCode, "sk")
        XCTAssertNil(decision.appleLanguagesWrite)
        XCTAssertFalse(decision.followSystemLanguage)
    }

    func testRegionalSettingsTagMapsToTheSupportedLanguage() {
        let decision = AppLanguageSettingsLogic.decide(
            snapshot(stored: "en", applied: nil, apple: ["hu-HU"])
        )

        XCTAssertEqual(decision.displayLanguageCode, "hu")
        XCTAssertEqual(decision.storedLanguageCode, "hu")
    }

    func testStoredChoiceIsPublishedWhenSettingsHasNoPerAppLanguage() {
        let decision = AppLanguageSettingsLogic.decide(
            snapshot(stored: "sk", applied: nil, apple: nil)
        )

        XCTAssertEqual(decision.displayLanguageCode, "sk")
        XCTAssertEqual(decision.appleLanguagesWrite, ["sk"])
        XCTAssertEqual(decision.appliedLanguageCode, "sk")
        XCTAssertFalse(decision.followSystemLanguage)
    }

    func testInSessionStoreChangeRepublishesAppleLanguages() {
        let decision = AppLanguageSettingsLogic.decide(
            snapshot(stored: "sk", applied: "hu", apple: ["hu"])
        )

        XCTAssertEqual(decision.displayLanguageCode, "sk")
        XCTAssertEqual(decision.appleLanguagesWrite, ["sk"])
        XCTAssertEqual(decision.appliedLanguageCode, "sk")
    }

    func testClearingThePerAppLanguageFollowsTheDevice() {
        let decision = AppLanguageSettingsLogic.decide(
            snapshot(stored: "hu", applied: "hu", apple: nil)
        )

        XCTAssertNil(decision.displayLanguageCode)
        XCTAssertNil(decision.storedLanguageCode)
        XCTAssertNil(decision.appliedLanguageCode)
        XCTAssertTrue(decision.followSystemLanguage)
        XCTAssertNil(decision.appleLanguagesWrite)
    }

    func testNothingChosenLeavesTheDeviceLocaleAlone() {
        let decision = AppLanguageSettingsLogic.decide(
            snapshot(stored: nil, applied: nil, apple: nil)
        )

        XCTAssertNil(decision.displayLanguageCode)
        XCTAssertNil(decision.storedLanguageCode)
        XCTAssertNil(decision.appleLanguagesWrite)
        XCTAssertFalse(decision.followSystemLanguage)
    }

    func testPerAppLanguageFillsAnEmptyStore() {
        let decision = AppLanguageSettingsLogic.decide(
            snapshot(stored: nil, applied: "sk", apple: ["sk"])
        )

        XCTAssertEqual(decision.displayLanguageCode, "sk")
        XCTAssertEqual(decision.storedLanguageCode, "sk")
        XCTAssertNil(decision.appleLanguagesWrite)
    }

    func testReconcileRoundTripsThroughUserDefaults() {
        let suite = "saleseverest.minit.tests.languageSettings"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suite)
        }

        defaults.set("hu", forKey: UserDefaultsAppLanguagePreferenceStore.defaultKey)

        AppLanguageSettingsReconciler.reconcile(defaults: defaults, domainName: suite)
        var snapshot = AppLanguageSettingsReconciler.snapshot(defaults: defaults, domainName: suite)
        XCTAssertEqual(snapshot.storedLanguageCode, "hu")
        XCTAssertEqual(snapshot.appliedLanguageCode, "hu")
        XCTAssertEqual(snapshot.appleLanguageCodes, ["hu"])
        XCTAssertFalse(snapshot.followSystemLanguage)

        defaults.set(["sk"], forKey: AppLanguageSettingsReconciler.appleLanguagesKey)
        AppLanguageSettingsReconciler.reconcile(defaults: defaults, domainName: suite)
        snapshot = AppLanguageSettingsReconciler.snapshot(defaults: defaults, domainName: suite)
        XCTAssertEqual(snapshot.storedLanguageCode, "sk")
        XCTAssertEqual(snapshot.appliedLanguageCode, "sk")
        XCTAssertEqual(snapshot.appleLanguageCodes, ["sk"])

        defaults.removeObject(forKey: AppLanguageSettingsReconciler.appleLanguagesKey)
        AppLanguageSettingsReconciler.reconcile(defaults: defaults, domainName: suite)
        snapshot = AppLanguageSettingsReconciler.snapshot(defaults: defaults, domainName: suite)
        XCTAssertNil(snapshot.storedLanguageCode)
        XCTAssertNil(snapshot.appliedLanguageCode)
        XCTAssertNil(snapshot.appleLanguageCodes)
        XCTAssertTrue(snapshot.followSystemLanguage)
    }

    private func snapshot(
        stored: String?,
        applied: String?,
        apple: [String]?
    ) -> AppLanguageSettingsSnapshot {
        AppLanguageSettingsSnapshot(
            storedLanguageCode: stored,
            appliedLanguageCode: applied,
            appleLanguageCodes: apple,
            followSystemLanguage: false
        )
    }
}
