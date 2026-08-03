/// Pure state machine backing `DSOTPField`, split out so its digit-parsing/auto-advance/
/// backspace-cascade logic can be unit tested directly instead of only indirectly through a
/// `View`'s private methods.
struct OTPFieldModel: Equatable {
    private(set) var digits: [String]
    var focusedIndex: Int?
    let length: Int

    init(code: String, length: Int) {
        self.length = length
        self.digits = Self.digits(from: code, length: length)
        self.focusedIndex = nil
    }

    var code: String { digits.joined() }

    /// Mirrors `DSOTPField`'s `.onAppear` — claims the first box only if nothing is
    /// already focused, so it doesn't fight a focus change that happened first.
    mutating func focusFirstBoxIfNeeded() {
        if focusedIndex == nil {
            focusedIndex = 0
        }
    }

    /// Reconciles an externally-set `code` (e.g. the caller clearing it) into per-box digits,
    /// guarded so it doesn't fight the boxes' own edits when nothing actually changed.
    mutating func syncExternalCode(_ newCode: String) {
        let resolved = Self.digits(from: newCode, length: length)
        if resolved != digits {
            digits = resolved
        }
    }

    /// One digit (already reduced to at most one character by the caller) was typed/pasted
    /// into box `index`. Advances focus to the next empty box, or drops focus entirely once
    /// the last box fills — there's nowhere left to advance to. Clearing a box (`digit`
    /// empty) that wasn't already empty steps focus back one box.
    mutating func applyDigit(_ digit: String, at index: Int) {
        let wasEmpty = digits[index].isEmpty
        digits[index] = digit

        if !digits[index].isEmpty {
            if index < length - 1 {
                focusedIndex = index + 1
            } else {
                focusedIndex = nil
            }
        } else if !wasEmpty, index > 0 {
            focusedIndex = index - 1
        }
    }

    /// Backspace pressed while box `index` was already empty — cascades back to the previous
    /// box, clearing its digit too, same as e.g. iOS's own SMS code field. No-ops on the first
    /// box.
    mutating func handleDeleteBackwardOnEmpty(at index: Int) {
        guard index > 0 else { return }
        digits[index - 1] = ""
        focusedIndex = index - 1
    }

    /// Parses a full code string into exactly `length` per-box digits: numeric characters
    /// beyond `length` are dropped, and short codes are right-padded with empty boxes.
    static func digits(from code: String, length: Int) -> [String] {
        let parsed = code.filter(\.isNumber).map(String.init)
        if parsed.count >= length {
            return Array(parsed.prefix(length))
        }
        return parsed + Array(repeating: "", count: length - parsed.count)
    }
}
