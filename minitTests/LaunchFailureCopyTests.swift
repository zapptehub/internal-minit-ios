import XCTest
@testable import minit

@MainActor
final class LaunchFailureCopyTests: XCTestCase {
    private struct AndroidCopy: Equatable {
        let title: String
        let message: String
    }

    /// Exact `app_flow_session_restore_failed_*` / `app_flow_onboarding_status_failed_*`
    /// values from Android `values/`, `values-hu/`, and `values-sk/`.
    private let android: [String: (session: AndroidCopy, onboarding: AndroidCopy)] = [
        "en": (
            session: AndroidCopy(
                title: "Unable to restore your session",
                message: "We couldn't check whether you're signed in. Check your connection and try again."
            ),
            onboarding: AndroidCopy(
                title: "Unable to check your onboarding status",
                message: "We couldn't check whether you can continue. Check your connection and try again."
            )
        ),
        "hu": (
            session: AndroidCopy(
                title: "Nem sikerült visszaállítani a munkamenetedet",
                message: "Nem sikerült ellenőriznünk, hogy be vagy-e jelentkezve. Ellenőrizd az internetkapcsolatodat, majd próbáld újra."
            ),
            onboarding: AndroidCopy(
                title: "Nem sikerült ellenőrizni a bevezetési folyamat állapotát",
                message: "Nem sikerült ellenőriznünk, hogy folytathatod-e. Ellenőrizd az internetkapcsolatodat, majd próbáld újra."
            )
        ),
        "sk": (
            session: AndroidCopy(
                title: "Reláciu sa nepodarilo obnoviť",
                message: "Nepodarilo sa overiť, či ste prihlásení. Skontrolujte pripojenie a skúste to znova."
            ),
            onboarding: AndroidCopy(
                title: "Nepodarilo sa overiť stav úvodného nastavenia",
                message: "Nepodarilo sa overiť, či môžete pokračovať. Skontrolujte pripojenie a skúste to znova."
            )
        )
    ]

    func testEachFailureStateShowsItsOwnAndroidCopy() throws {
        for language in ["en", "hu", "sk"] {
            let expected = try XCTUnwrap(android[language])
            let locale = Locale(identifier: language)
            let session = try XCTUnwrap(
                LaunchFailureCopy(state: .sessionRestoreFailed, locale: locale)
            )
            let onboarding = try XCTUnwrap(
                LaunchFailureCopy(state: .onboardingStatusFailed(userId: "user-1"), locale: locale)
            )

            XCTAssertEqual(session.title, expected.session.title, language)
            XCTAssertEqual(session.message, expected.session.message, language)
            XCTAssertEqual(onboarding.title, expected.onboarding.title, language)
            XCTAssertEqual(onboarding.message, expected.onboarding.message, language)
            XCTAssertNotEqual(session, onboarding, language)
            let retry = ["en": "Retry", "hu": "Újrapróbálás", "sk": "Skúsiť znova"][language]
            XCTAssertEqual(session.retry, retry, language)
            XCTAssertEqual(onboarding.retry, retry, language)
        }
    }

    func testOnboardingStatusCopyIgnoresUserId() throws {
        let locale = Locale(identifier: "en")
        let first = try XCTUnwrap(
            LaunchFailureCopy(state: .onboardingStatusFailed(userId: "user-1"), locale: locale)
        )
        let second = try XCTUnwrap(
            LaunchFailureCopy(state: .onboardingStatusFailed(userId: "user-2"), locale: locale)
        )
        XCTAssertEqual(first, second)
    }

    func testNonFailureStatesHaveNoLaunchFailureCopy() {
        let locale = Locale(identifier: "sk")
        XCTAssertNil(LaunchFailureCopy(state: .loading, locale: locale))
        XCTAssertNil(LaunchFailureCopy(state: .unauthenticated, locale: locale))
        XCTAssertNil(LaunchFailureCopy(state: .onboarding(userId: "user-1"), locale: locale))
        XCTAssertNil(LaunchFailureCopy(state: .authenticated(userId: "user-1"), locale: locale))
    }
}
