import XCTest
@testable import CoreExtensions

final class StringEmailValidationTests: XCTestCase {
    func testValidEmails() {
        XCTAssertTrue("new@minit.com".isValidEmail)
        XCTAssertTrue("iveta@minitbakery.com".isValidEmail)
        XCTAssertTrue("test+tag@example.co.uk".isValidEmail)
    }

    func testInvalidEmails() {
        XCTAssertFalse("".isValidEmail)
        XCTAssertFalse("iveta".isValidEmail)
        XCTAssertFalse("user@".isValidEmail)
        XCTAssertFalse("@domain.com".isValidEmail)
        XCTAssertFalse("user@domain".isValidEmail)
        XCTAssertFalse("user @domain.com".isValidEmail)
    }

    func testValidatesTrimmedInputAtCallSite() {
        XCTAssertTrue("  new@minit.com  ".trimmed.isValidEmail)
        XCTAssertFalse("  iveta  ".trimmed.isValidEmail)
    }
}
