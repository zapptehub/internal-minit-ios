import XCTest
@testable import CoreExtensions

final class DateExtensionsTests: XCTestCase {
    func testIsTodayIsTrueForNow() {
        XCTAssertTrue(Date().isToday)
    }

    func testIsTodayIsFalseForYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(yesterday.isToday)
    }

    func testIsYesterdayIsTrueForYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertTrue(yesterday.isYesterday)
    }

    func testIsYesterdayIsFalseForToday() {
        XCTAssertFalse(Date().isYesterday)
    }

    func testIsYesterdayIsFalseForTwoDaysAgo() {
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        XCTAssertFalse(twoDaysAgo.isYesterday)
    }

    func testAddingPositiveDaysMovesDateForward() {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())

        let result = base.adding(days: 3)

        XCTAssertEqual(result, calendar.date(byAdding: .day, value: 3, to: base))
    }

    func testAddingNegativeDaysMovesDateBackward() {
        let calendar = Calendar.current
        let base = calendar.startOfDay(for: Date())

        let result = base.adding(days: -2)

        XCTAssertEqual(result, calendar.date(byAdding: .day, value: -2, to: base))
    }

    func testAddingZeroDaysReturnsSameDate() {
        let base = Date()

        XCTAssertEqual(base.adding(days: 0), base)
    }

    func testFormattedUsesRequestedDateStyleWithNoTime() {
        var components = DateComponents()
        components.year = 2026
        components.month = 1
        components.day = 15
        let date = Calendar.current.date(from: components)!

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let expected = formatter.string(from: date)

        XCTAssertEqual(date.formatted(style: .medium), expected)
    }
}
