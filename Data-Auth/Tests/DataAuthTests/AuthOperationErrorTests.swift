import XCTest
import FirebaseAuth
@testable import DataAuth

final class AuthOperationErrorTests: XCTestCase {
    func testCredentialCodesMatchTheFirebaseAuthDomain() {
        XCTAssertEqual(AuthErrors.domain, "FIRAuthErrorDomain")
        XCTAssertEqual(AuthErrorCode.wrongPassword.rawValue, 17009)
        XCTAssertEqual(AuthErrorCode.invalidCredential.rawValue, 17004)
    }

    func testFirebaseAuthErrorCodesMapToOperationErrors() {
        let expected: [(AuthErrorCode, AuthOperationError)] = [
            (.invalidEmail, .invalidEmail),
            (.wrongPassword, .invalidCredentials),
            (.invalidCredential, .invalidCredentials),
            (.userNotFound, .invalidCredentials),
            (.invalidUserToken, .invalidCredentials),
            (.userTokenExpired, .invalidCredentials),
            (.emailAlreadyInUse, .emailAlreadyInUse),
            (.weakPassword, .weakPassword),
            (.userDisabled, .accountDisabled),
            (.networkError, .network),
            (.tooManyRequests, .tooManyRequests)
        ]

        for (code, operation) in expected {
            let error = NSError(
                domain: AuthErrors.domain,
                code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: "The password is invalid or the user does not have a password."]
            )
            XCTAssertEqual(AuthOperationError(error), operation, "\(code)")
            XCTAssertEqual(AuthOperationError(code), operation, "\(code) thrown as AuthErrorCode")
        }
    }

    func testUnmappedFirebaseCodesAreUnexpected() {
        let unmapped: [AuthErrorCode] = [
            .internalError,
            .operationNotAllowed,
            .webNetworkRequestFailed,
            .credentialAlreadyInUse,
            .accountExistsWithDifferentCredential
        ]
        for code in unmapped {
            let error = NSError(domain: AuthErrors.domain, code: code.rawValue)
            XCTAssertEqual(AuthOperationError(error), .unexpected, "\(code)")
        }
    }

    func testUnknownFirebaseCodeIsUnexpected() {
        let error = NSError(domain: AuthErrors.domain, code: 99999)
        XCTAssertEqual(AuthOperationError(error), .unexpected)
    }

    func testForeignDomainIsUnexpectedEvenWhenTheCodeMatches() {
        let error = NSError(
            domain: "OtherDomain",
            code: AuthErrorCode.wrongPassword.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "The password is invalid or the user does not have a password."]
        )
        XCTAssertEqual(AuthOperationError(error), .unexpected)
    }

    func testWrappedFirebaseAuthErrorIsClassifiedFromTheUnderlyingError() {
        let firebaseError = NSError(
            domain: AuthErrors.domain,
            code: AuthErrorCode.invalidCredential.rawValue
        )
        let wrapped = NSError(
            domain: "TaskFailed",
            code: 1,
            userInfo: [NSUnderlyingErrorKey: firebaseError]
        )
        XCTAssertEqual(AuthOperationError(wrapped), .invalidCredentials)
    }

    func testExistingOperationErrorIsNotRemapped() {
        XCTAssertEqual(AuthOperationError(AuthOperationError.network), .network)
    }
}
