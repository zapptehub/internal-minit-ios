import XCTest
import FirebaseAuth
@testable import DataAuth

final class AuthSessionErrorClassifierTests: XCTestCase {
    func testRevokedAuthErrorCodesAreClassifiedAsRevoked() {
        let codes = [
            AuthErrorCode.userTokenExpired.rawValue,
            AuthErrorCode.userDisabled.rawValue,
            AuthErrorCode.userNotFound.rawValue,
            AuthErrorCode.invalidUserToken.rawValue
        ]

        for code in codes {
            let error = NSError(domain: AuthErrors.domain, code: code)
            XCTAssertTrue(
                AuthSessionErrorClassifier.isRevokedSessionError(error),
                "Expected code \(code) to be treated as revoked"
            )
        }
    }

    func testNetworkStyleErrorIsNotClassifiedAsRevoked() {
        let error = NSError(domain: AuthErrors.domain, code: AuthErrorCode.networkError.rawValue)
        XCTAssertFalse(AuthSessionErrorClassifier.isRevokedSessionError(error))
    }

    func testForeignDomainErrorIsNotClassifiedAsRevoked() {
        let error = NSError(
            domain: "OtherDomain",
            code: AuthErrorCode.userTokenExpired.rawValue
        )
        XCTAssertFalse(AuthSessionErrorClassifier.isRevokedSessionError(error))
    }
}
