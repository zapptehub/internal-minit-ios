import SwiftUI
import XCTest
@testable import DesignSystem

@MainActor
final class DSMotionTests: XCTestCase {
    func testReduceMotionSnapsInsteadOfAnimating() {
        XCTAssertFalse(DSMotion.animates(reduceMotion: true))
        XCTAssertNil(DSMotion.animation(.default, reduceMotion: true))
        XCTAssertNil(DSMotion.animation(.easeInOut(duration: 0.32), reduceMotion: true))
        XCTAssertNil(DSMotion.animation(.linear(duration: 1.0 / 30.0), reduceMotion: true))
    }

    func testMotionPlaysWhenReduceMotionIsOff() {
        XCTAssertTrue(DSMotion.animates(reduceMotion: false))
        XCTAssertNotNil(DSMotion.animation(.default, reduceMotion: false))
        XCTAssertNil(
            DSMotion.animation(nil, reduceMotion: false),
            "an absent animation stays absent"
        )
    }

    func testPageIndicatorFillSnapsToTheEndState() {
        XCTAssertEqual(DSMotion.indicatorProgress(reduceMotion: true, animated: 0), 1)
        XCTAssertEqual(DSMotion.indicatorProgress(reduceMotion: true, animated: 0.4), 1)
        XCTAssertEqual(DSMotion.indicatorProgress(reduceMotion: false, animated: 0), 0)
        XCTAssertEqual(DSMotion.indicatorProgress(reduceMotion: false, animated: 0.4), 0.4)
    }

    func testPerformStillAppliesTheChange() {
        var value = 0
        DSMotion.perform(reduceMotion: true) { value = 1 }
        XCTAssertEqual(value, 1)
        DSMotion.perform(reduceMotion: false) { value = 2 }
        XCTAssertEqual(value, 2)
    }
}
