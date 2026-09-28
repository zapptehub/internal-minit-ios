import XCTest
import DataLoyaltyCard
@testable import FeatureOnboarding

final class OnboardingAnalyticsReasonTests: XCTestCase {
    func testCodeListMatchesAndroid() {
        XCTAssertEqual(
            Set(OnboardingAnalyticsReason.allCases.map(\.rawValue)),
            ["notFound", "alreadyClaimed", "alreadyLinked", "decoding", "server", "unknown"]
        )
    }

    func testEveryLoyaltyAndTransportSourceMapsToAFixedCode() {
        let cardNumber = "4111111111111111"
        let userId = "uid-9"
        let cases: [(Error, String)] = [
            (LoyaltyCardError.notFound, "notFound"),
            (LoyaltyCardError.alreadyClaimed, "alreadyClaimed"),
            (LoyaltyCardError.alreadyLinked, "alreadyLinked"),
            (LoyaltyCardError.underlying(.decoding), "decoding"),
            (
                LoyaltyCardError.underlying(.database(
                    domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
                    code: LoyaltyCardError.Underlying.firebasePermissionDeniedCode
                )),
                "server"
            ),
            (
                LoyaltyCardError.underlying(.database(
                    domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
                    code: LoyaltyCardError.Underlying.firebaseUnavailableCode
                )),
                "server"
            ),
            (
                LoyaltyCardError.underlying(.database(
                    domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
                    code: 9999
                )),
                "unknown"
            ),
            (
                LoyaltyCardError.underlying(.database(
                    domain: LoyaltyCardError.Underlying.firebaseDatabaseDomain,
                    code: 3
                )),
                "unknown"
            ),
            (
                LoyaltyCardError.underlying(.database(domain: "com.firebase.core", code: 1)),
                "unknown"
            ),
            (
                LoyaltyCardError.underlying(.database(
                    domain: NSURLErrorDomain,
                    code: URLError.notConnectedToInternet.rawValue
                )),
                "unknown"
            ),
            (
                LoyaltyCardError.underlying(.database(
                    domain: NSURLErrorDomain,
                    code: URLError.timedOut.rawValue
                )),
                "unknown"
            ),
            (LoyaltyCardError.underlying(.unknown), "unknown"),
            (
                NSError(
                    domain: "test",
                    code: 7,
                    userInfo: [
                        NSLocalizedDescriptionKey: "card \(cardNumber) user \(userId) https://db.example/users/\(userId)"
                    ]
                ),
                "unknown"
            ),
        ]

        for (error, expected) in cases {
            let reason = OnboardingAnalyticsReason.code(for: error)
            XCTAssertEqual(reason, expected)
            XCTAssertFalse(reason.contains(":"))
            XCTAssertFalse(reason.contains(cardNumber))
            XCTAssertFalse(reason.contains(userId))
            XCTAssertFalse(reason.contains("http"))
            XCTAssertTrue(OnboardingAnalyticsReason.allCases.map(\.rawValue).contains(reason))
        }
    }
}
