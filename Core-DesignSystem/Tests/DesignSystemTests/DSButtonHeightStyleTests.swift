import XCTest
@testable import DesignSystem

final class DSButtonHeightStyleTests: XCTestCase {
    func testHeightStylesMatchTheApprovedControlScale() {
        XCTAssertEqual(DSButtonHeightStyle.regular.value, 56)
        XCTAssertEqual(DSButtonHeightStyle.compact.value, 36)
        XCTAssertEqual(DSButtonHeightStyle.small.value, 32)
        XCTAssertEqual(DSButtonHeightStyle.large.value, 48)
        XCTAssertEqual(DSButtonHeightStyle.xLarge.value, 64)
    }
}
