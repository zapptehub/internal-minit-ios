import SwiftUI
import UIKit
import XCTest
@testable import FeatureLogin

/// Header traits and the invalid-email hint. Tap-target coverage lived in a file that
/// was removed with the 44pt hit-area work.
@MainActor
final class LoginAccessibilityTests: XCTestCase {
    func testLoginHeadlinesAreHeadersAndSupportingCopyIsNot() {
        let viewModel = LoginViewModel(authRepository: PreviewAuthRepository())
        viewModel.email = "iveta@minitbakery.com"
        let analytics = PreviewLoginAnalyticsTracking()

        assertHeader(
            "Enter your email address",
            notHeader: "We'll send you a verification code.",
            in: EmailEntryScreen(viewModel: viewModel, analytics: analytics)
        )
        assertHeader(
            "Welcome back Iveta",
            in: WelcomeBackScreen(viewModel: viewModel, analytics: analytics)
        )
        assertHeader(
            "Reset your password",
            notHeader: "We'll send you a password reset code. Enter this code at the next screen.",
            in: ForgotPasswordEmailScreen(viewModel: viewModel, analytics: analytics)
        )
        assertHeader(
            "Enter verification code",
            notHeader: "We've sent a verification code to iveta@minitbakery.com",
            in: VerificationCodeScreen(viewModel: viewModel, analytics: analytics, purpose: .signIn)
        )
        assertHeader(
            "Create a new account",
            notHeader: "It looks like this is your first time here! Create a new account to continue.",
            in: CreateAccountScreen(viewModel: viewModel, analytics: analytics)
        )
        assertHeader(
            "Password changed",
            notHeader: "Your new password has been saved successfully. Try logging in with it.",
            in: PasswordChangedScreen(analytics: analytics, onBackToLogin: {})
        )
    }

    private func assertHeader(
        _ label: String,
        notHeader: String? = nil,
        in view: some View,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let snapshot = LoginAccessibilitySnapshot(
            view
                .environment(\.locale, Locale(identifier: "en"))
                .frame(width: 402, height: 700)
        )
        let headlines = snapshot.nodes.filter { node in
            (node.label ?? "").replacingOccurrences(of: "\n", with: " ") == label
        }
        XCTAssertEqual(headlines.count, 1, snapshot.debugDescription, file: file, line: line)
        XCTAssertTrue(headlines[0].traits.contains(.header), snapshot.debugDescription, file: file, line: line)
        if let notHeader {
            let supporting = snapshot.nodes.filter { node in
                (node.label ?? "").replacingOccurrences(of: "\n", with: " ") == notHeader
            }
            XCTAssertEqual(supporting.count, 1, snapshot.debugDescription, file: file, line: line)
            XCTAssertFalse(supporting[0].traits.contains(.header), snapshot.debugDescription, file: file, line: line)
        }
    }
}

@MainActor
private struct LoginAccessibilitySnapshot {
    let nodes: [LoginAccessibilityNode]

    init(_ view: some View) {
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 800))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.6))
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        var collected: [LoginAccessibilityNode] = []
        var visited: Set<ObjectIdentifier> = []
        if let view = host.view {
            collectLoginAccessibility(view, into: &collected, visited: &visited)
        }
        nodes = collected
        window.isHidden = true
    }

    var debugDescription: String {
        nodes.map { node in
            "label=\(node.label ?? "-") value=\(node.value ?? "-") hint=\(node.hint ?? "-") traits=\(node.traitDescription) frame=\(node.frame)"
        }
        .joined(separator: "\n")
    }
}

private struct LoginAccessibilityNode {
    var label: String?
    var value: String?
    var hint: String?
    var traits: UIAccessibilityTraits
    var frame: CGRect

    var traitDescription: String {
        var names: [String] = []
        if traits.contains(.button) { names.append("button") }
        if traits.contains(.header) { names.append("header") }
        if traits.contains(.staticText) { names.append("staticText") }
        return names.isEmpty ? String(traits.rawValue) : names.joined(separator: ",")
    }
}

@MainActor
private func collectLoginAccessibility(
    _ object: Any,
    into nodes: inout [LoginAccessibilityNode],
    visited: inout Set<ObjectIdentifier>
) {
    guard let accessibility = unwrapLoginAccessibility(object) else { return }
    let identity = ObjectIdentifier(accessibility)
    guard visited.insert(identity).inserted else { return }
    if accessibility.accessibilityElementsHidden { return }
    if let view = accessibility as? UIView, view.isHidden { return }

    let label = accessibility.accessibilityLabel
    let value = accessibility.accessibilityValue
    let hint = accessibility.accessibilityHint
    if label?.isEmpty == false || value?.isEmpty == false || hint?.isEmpty == false {
        nodes.append(
            LoginAccessibilityNode(
                label: label,
                value: value,
                hint: hint?.isEmpty == true ? nil : hint,
                traits: accessibility.accessibilityTraits,
                frame: accessibility.accessibilityFrame
            )
        )
    }
    if let elements = accessibility.accessibilityElements {
        for element in elements {
            collectLoginAccessibility(element, into: &nodes, visited: &visited)
        }
    }
    guard let view = accessibility as? UIView else { return }
    let count = view.accessibilityElementCount()
    if count != NSNotFound, count > 0, count < 200 {
        for index in 0..<count {
            if let element = view.accessibilityElement(at: index) {
                collectLoginAccessibility(element, into: &nodes, visited: &visited)
            }
        }
    }
    for subview in view.subviews {
        collectLoginAccessibility(subview, into: &nodes, visited: &visited)
    }
}

private func unwrapLoginAccessibility(_ object: Any) -> NSObject? {
    let mirror = Mirror(reflecting: object)
    if mirror.displayStyle == .optional {
        guard let child = mirror.children.first else { return nil }
        return unwrapLoginAccessibility(child.value)
    }
    return object as? NSObject
}
