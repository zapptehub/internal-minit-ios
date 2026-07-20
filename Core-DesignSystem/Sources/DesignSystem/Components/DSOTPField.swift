import SwiftUI

/// A row of single-digit `DSInputField(type: .number)` boxes composed together to behave
/// like one verification-code field: typing a digit advances focus to the next box, and
/// deleting a digit moves focus back to the previous box. Reuses `DSInputField`'s existing
/// `.number` circle rather than introducing new visuals — see
/// `plans/ios-auth-flow-multi-step.md`.
///
/// Each box's visual state (border/value color) is driven by whether it's *filled*, not by
/// actual keyboard focus — a filled box keeps looking "focused" even after focus moves to
/// the next box, and an empty box looks like the plain default state even while it's the
/// one actually focused. See `DSInputField`'s `isFocusedOverride`.
public struct DSOTPField: View {
    private let label: String
    private let code: Binding<String>
    private let length: Int

    @State private var digits: [String]
    // Not `@FocusState`: each box now manages its own UIKit first-responder state manually
    // (see `DSInputField`'s `isFocusedBinding`/`onDeleteBackwardOnEmpty`), so this is just plain
    // state driving those boxes' derived `Binding<Bool>`s rather than real SwiftUI focus.
    @State private var focusedIndex: Int?

    /// - Parameters:
    ///   - label: Base accessibility label for each box (e.g. "Verification code digit") —
    ///     the box's 1-based position is appended by the component. `.number`'s circle has
    ///     no room for a visible label, same precedent as `DSInputField`.
    ///   - code: The full code as a single string, kept in sync with the per-box digits.
    ///   - length: Number of digit boxes. Defaults to 4 to match the current designs.
    public init(label: String, code: Binding<String>, length: Int = 4) {
        self.label = label
        self.code = code
        self.length = length
        self._digits = State(initialValue: Self.digits(from: code.wrappedValue, length: length))
    }

    public var body: some View {
        HStack(spacing: DSConstant.medium.value) {
            ForEach(0..<length, id: \.self) { index in
                DSInputField(
                    label: "\(label) \(index + 1)",
                    text: digitBinding(at: index),
                    type: .number,
                    // A filled box should look "focused" even after keyboard focus moves
                    // to the next box — and an empty box should look like the plain
                    // default state even while it's the one actually focused.
                    isFocusedOverride: !digits[index].isEmpty,
                    isFocusedBinding: isFocusedBinding(at: index),
                    onDeleteBackwardOnEmpty: { handleDeleteBackwardOnEmpty(at: index) }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            if focusedIndex == nil {
                focusedIndex = 0
            }
        }
        // Keeps the boxes in sync if the caller resets `code` externally (e.g. clearing it
        // when the screen re-appears) — guarded so it doesn't fight the boxes' own edits.
        .onChange(of: code.wrappedValue) { _, newValue in
            let resolved = Self.digits(from: newValue, length: length)
            if resolved != digits {
                digits = resolved
            }
        }
    }

    private func digitBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { digits[index] },
            // One digit per box is already enforced at the UIKit level (see
            // `DSNumberBoxTextField`'s delegate) — this is just the plain apply path.
            set: { newValue in applyDigit(String(newValue.filter(\.isNumber).suffix(1)), at: index) }
        )
    }

    /// Derives this box's actual-keyboard-focus as a plain `Binding<Bool>` from the shared
    /// `focusedIndex`, for `DSInputField`'s `isFocusedBinding` (see its doc comment for why a
    /// plain binding is needed here instead of `.focused($focusedIndex, equals: index)`).
    private func isFocusedBinding(at index: Int) -> Binding<Bool> {
        Binding(
            get: { focusedIndex == index },
            set: { isFocused in
                if isFocused {
                    focusedIndex = index
                } else if focusedIndex == index {
                    focusedIndex = nil
                }
            }
        )
    }

    /// Backspace pressed while box `index` was already empty (nothing left in it to delete via
    /// the normal `digitBinding` path) — cascades back to the previous box, clearing its digit
    /// too, same as e.g. iOS's own SMS code field. No-ops on the first box.
    private func handleDeleteBackwardOnEmpty(at index: Int) {
        guard index > 0 else { return }
        digits[index - 1] = ""
        code.wrappedValue = digits.joined()
        focusedIndex = index - 1
    }

    private func applyDigit(_ digit: String, at index: Int) {
        let wasEmpty = digits[index].isEmpty
        digits[index] = digit
        code.wrappedValue = digits.joined()

        if !digits[index].isEmpty {
            if index < length - 1 {
                focusedIndex = index + 1
            } else {
                // Last box just got filled — decline focus (dismiss the keyboard) instead of
                // leaving it there, since there's nowhere left to advance to and a still-focused
                // last box is what let it keep receiving keystrokes.
                focusedIndex = nil
            }
        } else if !wasEmpty, index > 0 {
            focusedIndex = index - 1
        }
    }

    private static func digits(from code: String, length: Int) -> [String] {
        let parsed = code.filter(\.isNumber).map(String.init)
        if parsed.count >= length {
            return Array(parsed.prefix(length))
        }
        return parsed + Array(repeating: "", count: length - parsed.count)
    }
}

#Preview("DSOTPField") {
    DSOTPFieldPreview()
}

private struct DSOTPFieldPreview: View {
    @State private var code = ""

    var body: some View {
        VStack(spacing: DSConstant.large.value) {
            DSOTPField(label: "Verification code digit", code: $code)
            Text("Code: \(code)")
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.secondary)
        }
        .padding(DSConstant.large.value)
        .background(DSColor.Background.Layer.level0)
    }
}
