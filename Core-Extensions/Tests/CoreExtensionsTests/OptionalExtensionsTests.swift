import XCTest
@testable import CoreExtensions

final class OptionalExtensionsTests: XCTestCase {
    func testOrReturnsWrappedValueWhenPresent() {
        let value: Int? = 5
        XCTAssertEqual(value.or(10), 5)
    }

    func testOrReturnsDefaultValueWhenNil() {
        let value: Int? = nil
        XCTAssertEqual(value.or(10), 10)
    }

    func testIsNilIsTrueForNilValue() {
        let value: Int? = nil
        XCTAssertTrue(value.isNil)
        XCTAssertFalse(value.isSome)
    }

    func testIsSomeIsTrueForNonNilValue() {
        let value: Int? = 1
        XCTAssertTrue(value.isSome)
        XCTAssertFalse(value.isNil)
    }
}
