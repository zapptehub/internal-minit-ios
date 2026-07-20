import XCTest
@testable import FeatureOnboarding

@MainActor
final class OnboardingProgressStoreTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "OnboardingProgressStoreTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testProgressIsScopedByUserId() throws {
        let store = UserDefaultsOnboardingProgressStore(
            userDefaults: userDefaults,
            keyPrefix: "test.onboarding"
        )

        try store.save(
            OnboardingProgress(step: .language, language: .sk),
            userId: "user-a"
        )

        XCTAssertEqual(try store.load(userId: "user-a")?.step, .supported(.language))
        XCTAssertEqual(try store.load(userId: "user-a")?.language, .sk)
        XCTAssertNil(try store.load(userId: "user-b"))
    }

    func testUnknownFutureStepIsPreserved() throws {
        let store = UserDefaultsOnboardingProgressStore(
            userDefaults: userDefaults,
            keyPrefix: "test.onboarding"
        )
        let progress = OnboardingProgress(
            persistedStep: .unsupported(rawValue: "futureStep"),
            language: .en,
            version: 7
        )

        try store.save(progress, userId: "user-a")

        XCTAssertEqual(try store.load(userId: "user-a"), progress)
        XCTAssertNil(try store.load(userId: "user-a")?.step.supportedStep)
    }

    func testClearRemovesOnlySelectedUsersProgress() throws {
        let store = UserDefaultsOnboardingProgressStore(
            userDefaults: userDefaults,
            keyPrefix: "test.onboarding"
        )
        try store.save(OnboardingProgress(step: .name), userId: "user-a")
        try store.save(OnboardingProgress(step: .language), userId: "user-b")

        store.clear(userId: "user-a")

        XCTAssertNil(try store.load(userId: "user-a"))
        XCTAssertEqual(try store.load(userId: "user-b")?.step, .supported(.language))
    }

    func testUnversionedLocalProgressUsesLegacyVersion() throws {
        let keyPrefix = "test.onboarding"
        let data = try JSONSerialization.data(withJSONObject: ["step": "name"])
        userDefaults.set(data, forKey: "\(keyPrefix).user-a")
        let store = UserDefaultsOnboardingProgressStore(
            userDefaults: userDefaults,
            keyPrefix: keyPrefix
        )

        let progress = try XCTUnwrap(store.load(userId: "user-a"))

        XCTAssertEqual(progress.version, OnboardingProgress.legacyVersion)
    }

    func testCorruptedProgressThrowsInsteadOfRestarting() {
        let keyPrefix = "test.onboarding"
        userDefaults.set(Data("not-json".utf8), forKey: "\(keyPrefix).user-a")
        let store = UserDefaultsOnboardingProgressStore(
            userDefaults: userDefaults,
            keyPrefix: keyPrefix
        )

        XCTAssertThrowsError(try store.load(userId: "user-a")) { error in
            XCTAssertEqual(error as? OnboardingProgressStoreError, .corruptedData)
        }
    }
}
