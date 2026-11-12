import Observation
import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Registration password entry used to swap `SecureField` and `TextField`, and the
/// secure field made iOS present "Use Strong Password?" on focus. These checks
/// lock typed text, keep login on saved-password AutoFill, and keep registration
/// off the password content types that present that sheet.
@MainActor
final class PasswordFieldStabilityTests: XCTestCase {
    func testPasswordFieldStaysOneControlWithSavedPasswordAutofill() throws {
        let probe = PasswordProbe(text: "Secret1")
        let host = PasswordFieldHost {
            PasswordEntryForm(probe: probe)
        }

        let field = try XCTUnwrap(host.passwordFields().first)
        let identity = ObjectIdentifier(field)
        XCTAssertEqual(field.textContentType, .password)
        XCTAssertNotEqual(field.textContentType, .newPassword)
        XCTAssertNil(field.passwordRules)
        XCTAssertTrue(field.isSecureTextEntry)
        XCTAssertEqual(field.text, "Secret1")
        XCTAssertFalse(field.clearsOnBeginEditing)
        XCTAssertFalse(field.clearsOnInsertion)

        field.textContentType = .newPassword
        field.passwordRules = UITextInputPasswordRules(descriptor: "minlength: 8;")
        XCTAssertEqual(field.textContentType, .password)
        XCTAssertNil(field.passwordRules)

        XCTAssertTrue(
            host.activate(label: "Show password"),
            host.accessibilityLabels().joined(separator: "\n")
        )
        host.settle()

        let afterToggle = host.passwordFields()
        XCTAssertEqual(afterToggle.count, 1)
        XCTAssertEqual(ObjectIdentifier(afterToggle[0]), identity)
        XCTAssertFalse(afterToggle[0].isSecureTextEntry)
        XCTAssertEqual(afterToggle[0].text, "Secret1")
        XCTAssertEqual(probe.text, "Secret1")
        XCTAssertEqual(afterToggle[0].textContentType, .password)

        probe.validation = .error
        host.settle()
        XCTAssertEqual(host.passwordFields().count, 1)
        XCTAssertEqual(ObjectIdentifier(host.passwordFields()[0]), identity)
        XCTAssertEqual(host.passwordFields()[0].text, "Secret1")
        XCTAssertEqual(probe.text, "Secret1")
    }

    func testTypedPasswordSurvivesRefocusAndFurtherTyping() throws {
        let probe = PasswordProbe(text: "")
        let host = PasswordFieldHost {
            PasswordEntryForm(probe: probe)
        }

        let field = try XCTUnwrap(host.passwordFields().first)
        XCTAssertTrue(field.becomeFirstResponder())
        field.insertText("abc")
        host.settle()
        XCTAssertEqual(field.text, "abc")
        XCTAssertEqual(probe.text, "abc")

        field.insertText("XYZ")
        host.settle()
        XCTAssertEqual(field.text, "abcXYZ")
        XCTAssertEqual(probe.text, "abcXYZ")

        XCTAssertTrue(field.resignFirstResponder())
        host.settle()
        XCTAssertTrue(field.becomeFirstResponder())
        host.settle(for: 0.35)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertEqual(field.text, "abcXYZ")
        XCTAssertEqual(probe.text, "abcXYZ")
        XCTAssertEqual(field.textContentType, .password)
    }

    func testRegistrationPasswordFieldsDoNotRequestAGeneratedPassword() throws {
        let probe = PasswordProbe(text: "first")
        let confirm = PasswordProbe(text: "second")
        let host = PasswordFieldHost {
            VStack {
                PasswordEntryForm(probe: probe, label: "Password", autofill: .userTyped)
                PasswordEntryForm(probe: confirm, label: "Re-Type Password", autofill: .userTyped)
            }
        }

        let fields = host.passwordFields()
        XCTAssertEqual(fields.count, 2)
        XCTAssertEqual(fields.map(\.text), ["first", "second"])
        for field in fields {
            XCTAssertEqual(field.textContentType, .oneTimeCode)
            XCTAssertNotEqual(field.textContentType, .newPassword)
            XCTAssertNotEqual(field.textContentType, .password)
            XCTAssertNil(field.passwordRules)
            XCTAssertTrue(field.isSecureTextEntry)
            field.textContentType = .newPassword
            XCTAssertEqual(field.textContentType, .oneTimeCode)
        }
    }
}

@MainActor
@Observable
private final class PasswordProbe {
    var text: String
    var validation: DSInputValidationState = .none

    init(text: String) {
        self.text = text
    }
}

@MainActor
private struct PasswordEntryForm: View {
    @Bindable var probe: PasswordProbe
    var label = "Password"
    var autofill: DSPasswordAutofill = .savedPassword

    var body: some View {
        DSInputField(
            label: label,
            text: $probe.text,
            type: .password,
            placeholder: "Value",
            validationState: probe.validation,
            passwordAutofill: autofill
        )
        .environment(\.locale, Locale(identifier: "en"))
    }
}

@MainActor
private struct PasswordFieldHost<Content: View> {
    let window: UIWindow
    let controller: UIHostingController<Content>

    init(@ViewBuilder content: () -> Content) {
        let host = UIHostingController(rootView: content())
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        self.window = window
        self.controller = host
        settle()
    }

    func settle(for interval: TimeInterval = 0.2) {
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }

    func passwordFields() -> [PasswordEntryTextField] {
        var matches: [PasswordEntryTextField] = []
        var visited: Set<ObjectIdentifier> = []
        collect(controller.view, into: &matches, visited: &visited)
        return matches
    }

    func accessibilityLabels() -> [String] {
        var labels: [String] = []
        var visited: Set<ObjectIdentifier> = []
        collectLabels(controller.view, into: &labels, visited: &visited)
        return labels
    }

    func activate(label: String) -> Bool {
        var matches: [NSObject] = []
        var visited: Set<ObjectIdentifier> = []
        collectLabeled(controller.view, label: label, into: &matches, visited: &visited)
        guard let match = matches.first else { return false }
        if match.accessibilityActivate() { return true }
        if let control = match as? UIControl {
            control.sendActions(for: .touchUpInside)
            return true
        }
        return false
    }

    private func collectLabels(
        _ object: Any,
        into labels: inout [String],
        visited: inout Set<ObjectIdentifier>
    ) {
        guard let accessibility = object as? NSObject else { return }
        let identity = ObjectIdentifier(accessibility)
        guard visited.insert(identity).inserted else { return }
        if let label = accessibility.accessibilityLabel, !label.isEmpty {
            labels.append(label)
        }
        if let elements = accessibility.accessibilityElements {
            for element in elements {
                collectLabels(element, into: &labels, visited: &visited)
            }
        }
        if let view = object as? UIView {
            for subview in view.subviews {
                collectLabels(subview, into: &labels, visited: &visited)
            }
        }
    }

    private func collectLabeled(
        _ object: Any,
        label: String,
        into matches: inout [NSObject],
        visited: inout Set<ObjectIdentifier>
    ) {
        guard let accessibility = object as? NSObject else { return }
        let identity = ObjectIdentifier(accessibility)
        guard visited.insert(identity).inserted else { return }
        if accessibility.accessibilityLabel == label {
            matches.append(accessibility)
        }
        if let elements = accessibility.accessibilityElements {
            for element in elements {
                collectLabeled(element, label: label, into: &matches, visited: &visited)
            }
        }
        if let view = object as? UIView {
            for subview in view.subviews {
                collectLabeled(subview, label: label, into: &matches, visited: &visited)
            }
        }
    }

    private func collect(
        _ view: UIView,
        into matches: inout [PasswordEntryTextField],
        visited: inout Set<ObjectIdentifier>
    ) {
        let identity = ObjectIdentifier(view)
        guard visited.insert(identity).inserted else { return }
        if let field = view as? PasswordEntryTextField {
            matches.append(field)
        }
        for subview in view.subviews {
            collect(subview, into: &matches, visited: &visited)
        }
    }
}
