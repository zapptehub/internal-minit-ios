import SwiftUI
import UIKit

/// One `UITextField` for both hidden and visible password entry.
///
/// SwiftUI's `if secure { SecureField } else { TextField }` builds a new control
/// on every eye tap. That new secure field has no content type, so iOS treats the
/// registration form (email keyboard + two secure fields) as account creation and
/// presents "Use Strong Password?" again. Dismissing that sheet resigns the field;
/// SwiftUI `@FocusState` then makes it first responder again, and the sheet returns.
///
/// This field stays put. Visibility only flips `isSecureTextEntry`. The content
/// type is fixed by the caller and is never `.newPassword`, which asks iOS to
/// generate a password and cover the form with "Use Strong Password?".
/// Login passes `.password` so a saved password can still be filled. Registration
/// passes `.oneTimeCode`: on that form `.password` still presents the sheet.
struct DSPasswordTextField: UIViewRepresentable {
    let text: Binding<String>
    let isSecure: Bool
    let isFocused: Binding<Bool>
    let textColor: Color
    let fontSize: CGFloat
    let isEnabled: Bool
    let accessibilityLabel: String
    let accessibilityHint: String?
    let contentType: UITextContentType

    func makeUIView(context: Context) -> PasswordEntryTextField {
        let textField = PasswordEntryTextField()
        textField.delegate = context.coordinator
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.keyboardType = .default
        textField.returnKeyType = .default
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.smartQuotesType = .no
        textField.smartDashesType = .no
        textField.smartInsertDeleteType = .no
        textField.inlinePredictionType = .no
        textField.lockedContentType = contentType
        textField.lockAutofill()
        textField.isSecureTextEntry = isSecure
        textField.clearsOnBeginEditing = false
        textField.clearsOnInsertion = false
        textField.font = .systemFont(ofSize: fontSize, weight: .regular)
        textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged),
            for: .editingChanged
        )
        if #available(iOS 18.0, *) {
            textField.writingToolsBehavior = .none
        }
        if #available(iOS 27.0, *) {
            textField.grammarCheckingType = .no
        }
        return textField
    }

    func updateUIView(_ uiView: PasswordEntryTextField, context: Context) {
        context.coordinator.text = text
        context.coordinator.isFocused = isFocused

        uiView.lockedContentType = contentType
        uiView.lockAutofill()
        uiView.isEnabled = isEnabled
        uiView.accessibilityLabel = accessibilityLabel
        uiView.accessibilityHint = accessibilityHint

        let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
        let wasEditing = uiView.isFirstResponder
        uiView.applySecureEntry(isSecure, preservedFont: font, textColor: UIColor(textColor))

        // The eye button can resign the field while SwiftUI applies the toggle.
        // Put the caret back once, on the next turn. Do not do this on every
        // update: re-asserting first responder is what brought the strong-password
        // sheet back after the user closed it.
        if wasEditing, isEnabled, !uiView.isFirstResponder {
            DispatchQueue.main.async {
                guard uiView.isEnabled, !uiView.isFirstResponder else { return }
                uiView.becomeFirstResponder()
            }
        }

        let bindingText = text.wrappedValue
        if uiView.text != bindingText, !uiView.isApplyingProgrammaticText {
            uiView.replaceText(bindingText, secure: uiView.isSecureTextEntry, font: font)
        }
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: PasswordEntryTextField,
        context: Context
    ) -> CGSize? {
        let line = uiView.font?.lineHeight ?? fontSize
        let proposedHeight = proposal.height ?? line
        return CGSize(
            width: proposal.width ?? uiView.intrinsicContentSize.width,
            height: max(proposedHeight, line)
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, isFocused: isFocused)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>
        var isFocused: Binding<Bool>

        init(text: Binding<String>, isFocused: Binding<Bool>) {
            self.text = text
            self.isFocused = isFocused
        }

        @objc func editingChanged(_ sender: UITextField) {
            guard let field = sender as? PasswordEntryTextField, !field.isApplyingProgrammaticText else {
                return
            }
            let value = sender.text ?? ""
            guard text.wrappedValue != value else { return }
            text.wrappedValue = value
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            (textField as? PasswordEntryTextField)?.lockAutofill()
            publishFocus(true)
        }

        /// Keystrokes update the binding from here as well as `.editingChanged`.
        /// A unit-test host has no `UIApplication`, so the control event is not
        /// delivered, but UIKit still calls this delegate method.
        func textFieldDidChangeSelection(_ textField: UITextField) {
            editingChanged(textField)
        }

        func textFieldDidEndEditing(_ textField: UITextField) {
            publishFocus(false)
        }

        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            textField.clearsOnInsertion = false
            return true
        }

        /// Publish after the UIKit callback returns so a SwiftUI update is not
        /// nested inside `updateUIView` or another field's editing callback.
        private func publishFocus(_ focused: Bool) {
            let isFocused = isFocused
            DispatchQueue.main.async {
                guard isFocused.wrappedValue != focused else { return }
                isFocused.wrappedValue = focused
            }
        }
    }
}

/// Secure entry that refuses the new-password content type.
///
/// iOS upgrades an unmarked secure field on a sign-up form to `.newPassword`
/// and presents "Use Strong Password?". The getter stays on `lockedContentType`
/// so that upgrade does not stick. Login locks `.password`. Registration locks
/// `.oneTimeCode`, because `.password` still presents the sheet on that form.
final class PasswordEntryTextField: UITextField {
    var isApplyingProgrammaticText = false
    var lockedContentType: UITextContentType = .password

    override var textContentType: UITextContentType! {
        get { lockedContentType }
        set { super.textContentType = lockedContentType }
    }

    /// Generation rules are what the strong-password sheet reads. Neither
    /// saved-password AutoFill nor typed registration passwords need them.
    override var passwordRules: UITextInputPasswordRules? {
        get { nil }
        set { super.passwordRules = nil }
    }

    func lockAutofill() {
        super.textContentType = lockedContentType
        passwordRules = nil
        clearsOnBeginEditing = false
        clearsOnInsertion = false
    }

    override func becomeFirstResponder() -> Bool {
        lockAutofill()
        let preserved = text
        let became = super.becomeFirstResponder()
        if isSecureTextEntry, let preserved, (text ?? "") != preserved {
            replaceText(preserved, secure: true, font: font ?? .systemFont(ofSize: 17))
        }
        lockAutofill()
        return became
    }

    /// Flipping `isSecureTextEntry` clears the string and resets the font.
    /// Put both back on this same field so the eye toggle does not drop characters.
    func applySecureEntry(_ secure: Bool, preservedFont: UIFont, textColor: UIColor) {
        let preserved = text ?? ""
        let selection = selectedTextRange
        if isSecureTextEntry != secure {
            isSecureTextEntry = secure
        }
        font = preservedFont
        self.textColor = textColor
        if (text ?? "") != preserved {
            replaceText(preserved, secure: isSecureTextEntry, font: preservedFont)
            selectedTextRange = selection
        }
    }

    func replaceText(_ newValue: String, secure: Bool, font: UIFont) {
        guard text != newValue else { return }
        isApplyingProgrammaticText = true
        defer {
            isApplyingProgrammaticText = false
            self.font = font
        }
        // Assigning `text` while secure often does not stick. Drop secure entry
        // for the assignment, then restore it before the next frame.
        if secure {
            isSecureTextEntry = false
            text = newValue
            isSecureTextEntry = true
        } else {
            text = newValue
        }
    }
}
