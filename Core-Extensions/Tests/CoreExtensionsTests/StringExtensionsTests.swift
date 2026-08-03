import XCTest
@testable import CoreExtensions

final class StringExtensionsTests: XCTestCase {
    func testTrimmedRemovesLeadingAndTrailingWhitespaceAndNewlines() {
        XCTAssertEqual("  hello \n".trimmed, "hello")
    }

    func testTrimmedLeavesInternalWhitespaceIntact() {
        XCTAssertEqual("  hello world  ".trimmed, "hello world")
    }

    func testIsBlankIsTrueForWhitespaceOnlyString() {
        XCTAssertTrue("   \n\t".isBlank)
    }

    func testIsBlankIsTrueForEmptyString() {
        XCTAssertTrue("".isBlank)
    }

    func testIsBlankIsFalseForNonWhitespaceString() {
        XCTAssertFalse(" hello ".isBlank)
    }

    func testCapitalizedFirstUppercasesOnlyFirstCharacter() {
        XCTAssertEqual("hello world".capitalizedFirst, "Hello world")
    }

    func testCapitalizedFirstReturnsSameStringWhenAlreadyCapitalized() {
        XCTAssertEqual("Hello".capitalizedFirst, "Hello")
    }

    func testCapitalizedFirstReturnsEmptyStringForEmptyInput() {
        XCTAssertEqual("".capitalizedFirst, "")
    }
}
