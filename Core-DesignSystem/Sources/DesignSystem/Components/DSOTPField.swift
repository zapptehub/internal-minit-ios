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

    // Not `@FocusState`: each box now manages its own UIKit first-responder state manually
    // (see `DSInputField`'s `isFocusedBinding`/`onDeleteBackwardOnEmpty`), so `OTPFieldModel`
    // just tracks plain state driving those boxes' derived `Binding<Bool>`s rather than real
    // SwiftUI focus. The digit-parsing/auto-advance/backspace-cascade logic itself lives there
    // (not here) so it can be unit tested as a plain value type.
    @State private var model: OTPFieldModel

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
        self._model = State(initialValue: OTPFieldModel(code: code.wrappedValue, length: length))
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
                    isFocusedOverride: !model.digits[index].isEmpty,
                    isFocusedBinding: isFocusedBinding(at: index),
                    onDeleteBackwardOnEmpty: {
                        model.handleDeleteBackwardOnEmpty(at: index)
                        code.wrappedValue = model.code
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            model.focusFirstBoxIfNeeded()
        }
        // Keeps the boxes in sync if the caller resets `code` externally (e.g. clearing it
        // when the screen re-appears) — guarded so it doesn't fight the boxes' own edits.
        .onChange(of: code.wrappedValue) { _, newValue in
            model.syncExternalCode(newValue)
        }
    }

    private func digitBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { model.digits[index] },
            // One digit per box is already enforced at the UIKit level (see
            // `DSNumberBoxTextField`'s delegate) — this is just the plain apply path.
            set: { newValue in
                model.applyDigit(String(newValue.filter(\.isNumber).suffix(1)), at: index)
                code.wrappedValue = model.code
            }
        )
    }

    /// Derives this box's actual-keyboard-focus as a plain `Binding<Bool>` from the shared
    /// `model.focusedIndex`, for `DSInputField`'s `isFocusedBinding` (see its doc comment for
    /// why a plain binding is needed here instead of `.focused($focusedIndex, equals: index)`).
    private func isFocusedBinding(at index: Int) -> Binding<Bool> {
        Binding(
            get: { model.focusedIndex == index },
            set: { isFocused in
                if isFocused {
                    model.focusedIndex = index
                } else if model.focusedIndex == index {
                    model.focusedIndex = nil
                }
            }
        )
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
