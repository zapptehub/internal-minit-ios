import XCTest
@testable import CoreExtensions

final class CollectionExtensionsTests: XCTestCase {
    func testSafeSubscriptReturnsElementForValidIndex() {
        let array = [10, 20, 30]
        XCTAssertEqual(array[safe: 1], 20)
    }

    func testSafeSubscriptReturnsNilForOutOfBoundsIndex() {
        let array = [10, 20, 30]
        XCTAssertNil(array[safe: 5])
        XCTAssertNil(array[safe: -1])
    }

    func testSafeSubscriptReturnsNilForEmptyCollection() {
        let array: [Int] = []
        XCTAssertNil(array[safe: 0])
    }

    func testChunkedSplitsIntoEqualGroups() {
        let array = [1, 2, 3, 4, 5, 6]
        XCTAssertEqual(array.chunked(into: 2), [[1, 2], [3, 4], [5, 6]])
    }

    func testChunkedKeepsRemainderInLastGroup() {
        let array = [1, 2, 3, 4, 5]
        XCTAssertEqual(array.chunked(into: 2), [[1, 2], [3, 4], [5]])
    }

    func testChunkedWithSizeLargerThanCountReturnsSingleGroup() {
        let array = [1, 2]
        XCTAssertEqual(array.chunked(into: 10), [[1, 2]])
    }

    func testChunkedReturnsEmptyArrayForZeroSize() {
        let array = [1, 2, 3]
        XCTAssertEqual(array.chunked(into: 0), [])
    }

    func testChunkedReturnsEmptyArrayForNegativeSize() {
        let array = [1, 2, 3]
        XCTAssertEqual(array.chunked(into: -1), [])
    }

    func testChunkedReturnsEmptyArrayForEmptyInput() {
        let array: [Int] = []
        XCTAssertEqual(array.chunked(into: 3), [])
    }
}
