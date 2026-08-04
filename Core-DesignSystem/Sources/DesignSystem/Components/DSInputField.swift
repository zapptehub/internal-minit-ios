import SwiftUI

// Figma: https://www.figma.com/design/XDtLIOc3QdetbZ8h5Q7QVz/Minit---Application?node-id=2110-977

/// The six input shapes shown in the Figma "Input" frame. All types except `.number`
/// share `DSInputBorderedContainer`'s rounded-rect + floating-label layout; `.number` is a
/// small fixed circle with no visible label/description (see `DSInputField.body`).
public enum DSInputFieldType: Equatable {
    case text
    case password
    case date
    case unit(suffix: String)
    case textarea(maxLength: Int?)
    case number
}

/// A single design-system text input, covering every type/state combination in the
/// Figma "Input" frame (`DSInputFieldType` × `DSInputValidationState` × focus/filled × enabled).
///
/// Deliberately binds to plain `String` for every type, including `.date` and `.number`
/// — formatting/parsing (e.g. a `Date` into `"DD / MM / YYYY"`, or clamping `.number` to
/// digits) is the caller's responsibility, consistent with the DS rule that components own
/// *appearance*, not business logic. See `plans/ios-ds-form-components.md` for the reasoning.
public struct DSInputField: View {
    private let label: String?
    private let text: Binding<String>
    private let type: DSInputFieldType
    private let description: String?
    private let placeholder: String?
    private let validationState: DSInputValidationState
    private let isEnabled: Bool
    private let keyboardTypeOverride: UIKeyboardType?
    private let onCalendarTap: (() -> Void)?
    private let isFocusedOverride: Bool?
    private let isFocusedBinding: Binding<Bool>?
    private let onDeleteBackwardOnEmpty: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var isSecureTextHidden = true

    public init(
        /// The floating label overlaid on the border (or, for `.number`, an accessibility-only
        /// label since that variant has no room for a visible one). `nil` renders no label at
        /// all — e.g. `DSOTPField` builds its own per-box accessibility label instead.
        label: String? = nil,
        text: Binding<String>,
        type: DSInputFieldType = .text,
        description: String? = nil,
        placeholder: String? = nil,
        validationState: DSInputValidationState = .none,
        isEnabled: Bool = true,
        /// Overrides the type's default keyboard type. Leave `nil` in the common case —
        /// each type already implies the right keyboard (see `resolvedKeyboardType`).
        keyboardTypeOverride: UIKeyboardType? = nil,
        /// Only used by `.date` — the trailing calendar icon is decorative unless this is
        /// provided, in which case tapping it invokes the caller's own date picker/sheet.
        onCalendarTap: (() -> Void)? = nil,
        /// Drives the focus-dependent border/value colors instead of actual keyboard focus
        /// when non-`nil`. Leave `nil` in the common case (real focus). Added for
        /// `DSOTPField`'s digit boxes, which need to look "focused" once filled even after
        /// keyboard focus moves to the next box — actual focus/keyboard behavior (via
        /// `.focused($isFocused)` below) is untouched either way.
        isFocusedOverride: Bool? = nil,
        /// Only used by `.number`, and only meaningful together with `onDeleteBackwardOnEmpty`
        /// (both non-`nil`, as `DSOTPField` does). When set, the box's actual keyboard focus is
        /// driven by this binding instead of SwiftUI's own `.focused()`/`@FocusState` — needed
        /// because the UIKit-backed field used in that case (see `onDeleteBackwardOnEmpty`)
        /// isn't automatically wired into SwiftUI's focus system the way native `TextField` is.
        isFocusedBinding: Binding<Bool>? = nil,
        /// Only used by `.number`, and only when `isFocusedBinding` is also set. Called when
        /// backspace is pressed while the box is already empty — a plain SwiftUI `TextField`
        /// can't report this (no text change to diff against), so this box switches to a
        /// UIKit-backed field that overrides `deleteBackward()` directly. `DSOTPField` uses
        /// this to jump focus back to (and clear) the previous digit box.
        onDeleteBackwardOnEmpty: (() -> Void)? = nil
    ) {
        self.label = label
        self.text = text
        self.type = type
        self.description = description
        self.placeholder = placeholder
        self.validationState = validationState
        self.isEnabled = isEnabled
        self.keyboardTypeOverride = keyboardTypeOverride
        self.onCalendarTap = onCalendarTap
        self.isFocusedOverride = isFocusedOverride
        self.isFocusedBinding = isFocusedBinding
        self.onDeleteBackwardOnEmpty = onDeleteBackwardOnEmpty
    }

    public var body: some View {
        let colors = DSInputFieldColors(
            isEnabled: isEnabled,
            isFocused: isFocusedOverride ?? isFocused,
            isFilled: !text.wrappedValue.isEmpty,
            validationState: validationState
        )

        VStack(alignment: .leading, spacing: DSInputFieldMetrics.descriptionSpacing) {
            fieldContent(colors: colors)

            if let description, !isNumberType {
                DSInputDescription(text: description, color: colors.descriptionColor)
            }
        }
        .autocorrectionDisabled()
        .disabled(!isEnabled)
    }

    private var isNumberType: Bool {
        if case .number = type { return true }
        return false
    }

    private var resolvedKeyboardType: UIKeyboardType {
        if let keyboardTypeOverride { return keyboardTypeOverride }
        switch type {
        case .text, .password, .date, .textarea: return .default
        case .unit: return .decimalPad
        case .number: return .numberPad
        }
    }

    @ViewBuilder
    private func fieldContent(colors: DSInputFieldColors) -> some View {
        switch type {
        case .text, .date, .unit:
            DSInputBorderedContainer(label: label, colors: colors) {
                HStack(spacing: DSInputFieldMetrics.trailingAccessorySpacing) {
                    TextField(placeholder ?? "", text: text)
                        .typography(.uiLargeRegular)
                        .foregroundColor(colors.valueColor)
                        .keyboardType(resolvedKeyboardType)
                        .focused($isFocused)
                    trailingAccessory(colors: colors)
                }
            }
        case .password:
            DSInputBorderedContainer(label: label, colors: colors) {
                HStack(spacing: DSInputFieldMetrics.trailingAccessorySpacing) {
                    Group {
                        if isSecureTextHidden {
                            SecureField(placeholder ?? "", text: text)
                        } else {
                            TextField(placeholder ?? "", text: text)
                        }
                    }
                    .typography(.uiLargeRegular)
                    .foregroundColor(colors.valueColor)
                    .focused($isFocused)

                    Button {
                        isSecureTextHidden.toggle()
                    } label: {
                        DSIconView(icon: isSecureTextHidden ? .eye : .eyeSlash, color: colors.valueColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSecureTextHidden ? "Show password" : "Hide password")
                }
            }
        case .textarea(let maxLength):
            DSInputBorderedContainer(label: label, colors: colors, height: DSInputFieldMetrics.textareaHeight) {
                VStack(alignment: .leading, spacing: DSInputFieldMetrics.trailingAccessorySpacing) {
                    TextField(placeholder ?? "", text: text, axis: .vertical)
                        .typography(.uiLargeRegular)
                        .foregroundColor(colors.valueColor)
                        .focused($isFocused)
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        Text(characterCountText(maxLength: maxLength))
                            .typography(.uiRegular)
                            .foregroundColor(colors.descriptionColor)
                    }
                }
            }
        case .number:
            numberField(colors: colors)
        }
    }

    @ViewBuilder
    private func trailingAccessory(colors: DSInputFieldColors) -> some View {
        switch type {
        case .date:
            Button {
                onCalendarTap?()
            } label: {
                DSIconView(icon: .calendar, color: colors.valueColor)
            }
            .buttonStyle(.plain)
        case .unit(let suffix):
            Text(suffix)
                .typography(.uiRegular)
                .foregroundColor(colors.descriptionColor)
        default:
            EmptyView()
        }
    }

    private func characterCountText(maxLength: Int?) -> String {
        let count = text.wrappedValue.count
        if let maxLength {
            return "\(count)/\(maxLength)"
        }
        return "\(count)"
    }

    /// `.number`'s circle has no room for a floating label or description in Figma — the
    /// label is exposed as an accessibility label instead of visible text.
    private func numberField(colors: DSInputFieldColors) -> some View {
        ZStack {
            Circle()
                .strokeBorder(colors.borderColor, lineWidth: colors.borderWidth)
            if let isFocusedBinding, let onDeleteBackwardOnEmpty {
                DSNumberBoxTextField(
                    text: text,
                    isFocused: isFocusedBinding,
                    textColor: colors.valueColor,
                    onDeleteBackwardOnEmpty: onDeleteBackwardOnEmpty
                )
            } else {
                TextField("", text: text)
                    .typography(.uiLargeRegular)
                    .foregroundColor(colors.valueColor)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .focused($isFocused)
            }
        }
        .frame(width: DSInputFieldMetrics.numberCircleDiameter, height: DSInputFieldMetrics.numberCircleDiameter)
        .accessibilityLabel(label ?? "")
    }
}

/// UIKit-backed replacement for `TextField`, used only by `.number` boxes that need to detect
/// a backspace press on an already-empty field (`DSOTPField`'s "jump back to the previous box"
/// behavior). SwiftUI's `TextField` + `.onChange(of:)` genuinely cannot see this case — there's
/// no text change to diff against when there's nothing to delete — but `UITextField` calls
/// `deleteBackward()` on every delete-key tap (hardware or on-screen) regardless of whether
/// anything gets deleted, so overriding it works unconditionally.
///
/// Manages first-responder state itself via `isFocused` instead of SwiftUI's `.focused()` /
/// `@FocusState`, which isn't automatically bridged to custom `UIViewRepresentable`s the way it
/// is for native controls like `TextField`.
private struct DSNumberBoxTextField: UIViewRepresentable {
    let text: Binding<String>
    let isFocused: Binding<Bool>
    let textColor: Color
    let onDeleteBackwardOnEmpty: () -> Void

    func makeUIView(context: Context) -> BackspaceDetectingTextField {
        let textField = BackspaceDetectingTextField()
        textField.delegate = context.coordinator
        textField.keyboardType = .numberPad
        textField.textAlignment = .center
        textField.autocorrectionType = .no
        // Kept in sync by hand with `FontType.uiLargeRegular` (`.system(size: 17, weight:
        // .regular)`) — there's no public SwiftUI `Font` -> `UIFont` bridge to derive this from.
        textField.font = .systemFont(ofSize: 17, weight: .regular)
        // `tintColor` drives the text-input cursor (caret) and selection handles — black per
        // design, rather than the system/accent tint a plain `TextField` would otherwise pick up.
        textField.tintColor = .black
        textField.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged), for: .editingChanged)
        textField.onDeleteBackwardWhileEmpty = { [coordinator = context.coordinator] in
            coordinator.onDeleteBackwardOnEmpty()
        }
        return textField
    }

    func updateUIView(_ uiView: BackspaceDetectingTextField, context: Context) {
        if uiView.text != text.wrappedValue {
            uiView.text = text.wrappedValue
        }
        uiView.textColor = UIColor(textColor)
        context.coordinator.onDeleteBackwardOnEmpty = onDeleteBackwardOnEmpty

        // Deferred to the next run loop turn: this `updateUIView` call is itself happening
        // *inside* another box's UIKit delegate/target-action callback (typing/backspace on the
        // box that's handing off focus), which is still unwinding on the call stack. Calling
        // `becomeFirstResponder()`/`resignFirstResponder()` on a *different* text field
        // synchronously from in there is a well-known UIKit foot-gun — the responder-chain
        // transition starts before the previous one has finished, so the new field ends up
        // looking focused but not actually receiving keystrokes (a real, user-initiated tap
        // works fine, since that isn't nested inside another field's callback).
        let isFocused = isFocused
        if isFocused.wrappedValue != uiView.isFirstResponder {
            DispatchQueue.main.async {
                if isFocused.wrappedValue, !uiView.isFirstResponder {
                    uiView.becomeFirstResponder()
                } else if !isFocused.wrappedValue, uiView.isFirstResponder {
                    uiView.resignFirstResponder()
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, isFocused: isFocused, onDeleteBackwardOnEmpty: onDeleteBackwardOnEmpty)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let text: Binding<String>
        private let isFocused: Binding<Bool>
        var onDeleteBackwardOnEmpty: () -> Void

        init(text: Binding<String>, isFocused: Binding<Bool>, onDeleteBackwardOnEmpty: @escaping () -> Void) {
            self.text = text
            self.isFocused = isFocused
            self.onDeleteBackwardOnEmpty = onDeleteBackwardOnEmpty
        }

        @objc func editingChanged(_ sender: UITextField) {
            text.wrappedValue = sender.text ?? ""
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            isFocused.wrappedValue = true
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            isFocused.wrappedValue = false
        }

        /// Enforces "one digit per box" at the UIKit level — the actual source of the earlier
        /// "last box accepts many digits" bug was that nothing stopped a `UITextField` from
        /// accumulating extra characters once it had one. Digits (including a paste of several)
        /// replace the box's single digit with the last character rather than appending.
        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            guard !string.isEmpty else { return true } // let `deleteBackward()` handle deletion
            guard string.allSatisfy(\.isNumber) else { return false }

            let digit = String(string.suffix(1))
            textField.text = digit
            text.wrappedValue = digit
            return false
        }
    }
}

/// Plain `UITextField` subclass whose only job is noticing `deleteBackward()` calls that had
/// nothing to delete — see `DSNumberBoxTextField`.
private final class BackspaceDetectingTextField: UITextField {
    var onDeleteBackwardWhileEmpty: (() -> Void)?

    override func deleteBackward() {
        let wasEmpty = text?.isEmpty ?? true
        super.deleteBackward()
        if wasEmpty {
            onDeleteBackwardWhileEmpty?()
        }
    }
}

#Preview("DSInputField — types") {
    DSInputFieldTypesPreview()
}

/// Wrapper view so each type can hold its own `@State` text binding (`#Preview` closures
/// can't declare `@State` directly).
private struct DSInputFieldTypesPreview: View {
    @State private var text = ""
    @State private var password = ""
    @State private var date = ""
    @State private var unitValue = "72"
    @State private var textareaValue = "Long-form notes go here."
    @State private var number = "3"

    @State private var errorText = ""
    @State private var disabledText = "Can't edit this"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSConstant.large.value) {
                DSInputField(label: "Text", text: $text, description: "Input description")
                DSInputField(label: "Password", text: $password, type: .password, description: "Input description")
                DSInputField(label: "Date", text: $date, type: .date, description: "Input description", placeholder: "Value / Value / Value")
                DSInputField(label: "Unit", text: $unitValue, type: .unit(suffix: "°C"), description: "Input description")
                DSInputField(label: "Textarea", text: $textareaValue, type: .textarea(maxLength: 100), description: "Input description")

                HStack(spacing: DSConstant.medium.value) {
                    DSInputField(label: "Number", text: $number, type: .number)
                    DSInputField(label: "Number", text: .constant(""), type: .number, validationState: .error)
                    DSInputField(label: "Number", text: .constant("5"), type: .number, validationState: .success)
                    DSInputField(label: "Number", text: .constant(""), type: .number, isEnabled: false)
                }

                DSInputField(
                    label: "Text",
                    text: $errorText,
                    description: "Input description",
                    validationState: .error
                )
                DSInputField(
                    label: "Text",
                    text: $disabledText,
                    description: "Input description",
                    isEnabled: false
                )
            }
            .padding(DSConstant.large.value)
        }
        .background(DSColor.Background.Layer.level0)
    }
}
