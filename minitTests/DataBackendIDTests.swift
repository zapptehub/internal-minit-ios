import XCTest
@testable import minit

final class DataBackendIDTests: XCTestCase {
    func testResolveDataBackendID() {
        XCTAssertEqual(resolveDataBackendID(" http "), .success("http"))
        XCTAssertEqual(resolveDataBackendID(""), .failure(.missingOrUnexpanded))
        XCTAssertEqual(resolveDataBackendID("$(X)"), .failure(.missingOrUnexpanded))
        XCTAssertEqual(resolveDataBackendID("firebase"), .failure(.removedFirebase))
        XCTAssertEqual(resolveDataBackendID("foo"), .failure(.unknown("foo")))
    }
}
