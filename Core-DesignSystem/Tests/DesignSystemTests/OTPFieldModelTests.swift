import XCTest
@testable import DesignSystem

final class OTPFieldModelTests: XCTestCase {
    // MARK: - Init / digit parsing

    func testInitWithEmptyCodePadsAllBoxesEmpty() {
        let model = OTPFieldModel(code: "", length: 4)

        XCTAssertEqual(model.digits, ["", "", "", ""])
        XCTAssertEqual(model.code, "")
    }

    func testInitWithPartialCodeRightPadsRemainingBoxes() {
        let model = OTPFieldModel(code: "12", length: 4)

        XCTAssertEqual(model.digits, ["1", "2", "", ""])
    }

    func testInitWithFullCodeFillsAllBoxes() {
        let model = OTPFieldModel(code: "1234", length: 4)

        XCTAssertEqual(model.digits, ["1", "2", "3", "4"])
        XCTAssertEqual(model.code, "1234")
    }

    func testInitTruncatesCodeLongerThanLength() {
        let model = OTPFieldModel(code: "123456", length: 4)

        XCTAssertEqual(model.digits, ["1", "2", "3", "4"])
    }

    func testInitFiltersOutNonNumericCharacters() {
        let model = OTPFieldModel(code: "1a2b", length: 4)

        XCTAssertEqual(model.digits, ["1", "2", "", ""])
    }

    func testFocusedIndexStartsNil() {
        let model = OTPFieldModel(code: "", length: 4)

        XCTAssertNil(model.focusedIndex)
    }

    // MARK: - focusFirstBoxIfNeeded

    func testFocusFirstBoxIfNeededFocusesBoxZeroWhenNothingIsFocused() {
        var model = OTPFieldModel(code: "", length: 4)

        model.focusFirstBoxIfNeeded()

        XCTAssertEqual(model.focusedIndex, 0)
    }

    func testFocusFirstBoxIfNeededDoesNotOverrideExistingFocus() {
        var model = OTPFieldModel(code: "", length: 4)
        model.focusedIndex = 2

        model.focusFirstBoxIfNeeded()

        XCTAssertEqual(model.focusedIndex, 2)
    }

    // MARK: - applyDigit: auto-advance

    func testApplyDigitAdvancesFocusToNextBox() {
        var model = OTPFieldModel(code: "", length: 4)

        model.applyDigit("5", at: 0)

        XCTAssertEqual(model.digits, ["5", "", "", ""])
        XCTAssertEqual(model.focusedIndex, 1)
    }

    func testApplyDigitOnLastBoxDropsFocusEntirely() {
        var model = OTPFieldModel(code: "123", length: 4)

        model.applyDigit("4", at: 3)

        XCTAssertEqual(model.digits, ["1", "2", "3", "4"])
        XCTAssertNil(model.focusedIndex)
    }

    func testApplyDigitUpdatesCodeByJoiningAllBoxesInOrder() {
        var model = OTPFieldModel(code: "12", length: 4)

        model.applyDigit("9", at: 2)

        // `code` is a plain concatenation of the per-box digits — empty boxes contribute
        // nothing (no placeholder characters), so a still-partial code reads shorter than
        // `length`.
        XCTAssertEqual(model.code, "129")
    }

    // MARK: - applyDigit: clearing a box

    func testClearingANonEmptyBoxStepsFocusBackOneBox() {
        var model = OTPFieldModel(code: "12", length: 4)

        model.applyDigit("", at: 1)

        XCTAssertEqual(model.digits, ["1", "", "", ""])
        XCTAssertEqual(model.focusedIndex, 0)
    }

    func testClearingTheFirstBoxDoesNotMoveFocusBackward() {
        var model = OTPFieldModel(code: "1", length: 4)

        model.applyDigit("", at: 0)

        XCTAssertEqual(model.digits, ["", "", "", ""])
        XCTAssertNil(model.focusedIndex)
    }

    func testClearingAnAlreadyEmptyBoxIsANoOpForFocus() {
        var model = OTPFieldModel(code: "", length: 4)
        model.focusedIndex = 2

        model.applyDigit("", at: 2)

        XCTAssertEqual(model.focusedIndex, 2)
    }

    // MARK: - handleDeleteBackwardOnEmpty

    func testDeleteBackwardOnEmptyClearsPreviousBoxAndMovesFocusBack() {
        var model = OTPFieldModel(code: "12", length: 4)
        model.focusedIndex = 2

        model.handleDeleteBackwardOnEmpty(at: 2)

        XCTAssertEqual(model.digits, ["1", "", "", ""])
        XCTAssertEqual(model.focusedIndex, 1)
    }

    func testDeleteBackwardOnEmptyAtFirstBoxIsANoOp() {
        var model = OTPFieldModel(code: "", length: 4)
        model.focusedIndex = 0

        model.handleDeleteBackwardOnEmpty(at: 0)

        XCTAssertEqual(model.digits, ["", "", "", ""])
        XCTAssertEqual(model.focusedIndex, 0)
    }

    // MARK: - syncExternalCode

    func testSyncExternalCodeUpdatesDigitsWhenCodeActuallyChanged() {
        var model = OTPFieldModel(code: "12", length: 4)

        model.syncExternalCode("99")

        XCTAssertEqual(model.digits, ["9", "9", "", ""])
    }

    func testSyncExternalCodeToEmptyStringClearsAllBoxes() {
        var model = OTPFieldModel(code: "1234", length: 4)

        model.syncExternalCode("")

        XCTAssertEqual(model.digits, ["", "", "", ""])
    }

    func testSyncExternalCodeIsANoOpWhenResolvedDigitsAreUnchanged() {
        var model = OTPFieldModel(code: "12", length: 4)
        model.focusedIndex = 1

        // Same resolved digits as the current state (e.g. the view echoing back its own
        // `code.wrappedValue` update) — must not perturb `focusedIndex` or digits identity.
        model.syncExternalCode("12")

        XCTAssertEqual(model.digits, ["1", "2", "", ""])
        XCTAssertEqual(model.focusedIndex, 1)
    }

    // MARK: - Equatable

    func testModelsWithSameDigitsFocusAndLengthAreEqual() {
        var a = OTPFieldModel(code: "12", length: 4)
        var b = OTPFieldModel(code: "12", length: 4)
        a.focusedIndex = 1
        b.focusedIndex = 1

        XCTAssertEqual(a, b)
    }
}
