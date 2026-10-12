import SwiftUI
import UIKit
import XCTest
@testable import minit

@MainActor
final class LaunchFailedAccessibilityTests: XCTestCase {
    func testFailureTitleIsAHeaderAndAnnouncesAssertively() throws {
        let cases: [(AppFlowViewModel.State, String)] = [
            (.sessionRestoreFailed, "Unable to restore your session"),
            (.onboardingStatusFailed(userId: "user-1"), "Unable to check your onboarding status"),
        ]

        for (state, title) in cases {
            let copy = try XCTUnwrap(LaunchFailureCopy(state: state, locale: Locale(identifier: "en")))
            let log = LaunchAnnouncementLog()
            let snapshot = LaunchFailureAccessibilitySnapshot(
                LaunchFailedView(state: state, announce: { announcedTitle, announcedMessage in
                    log.messages.append(LaunchFailureAnnouncement.spoken(title: announcedTitle, message: announcedMessage))
                }, onRetry: {})
                .environment(\.locale, Locale(identifier: "en"))
            )

            let headers = snapshot.nodes.filter { $0.traits.contains(.header) }
            XCTAssertEqual(headers.map(\.label), [title], snapshot.debugDescription)
            XCTAssertEqual(copy.title, title)

            let retry = snapshot.nodes.filter { $0.label == "Retry" }
            XCTAssertEqual(retry.count, 1, snapshot.debugDescription)
            XCTAssertFalse(retry[0].traits.contains(.header), snapshot.debugDescription)
            XCTAssertTrue(retry[0].traits.contains(.button), snapshot.debugDescription)

            XCTAssertFalse(
                snapshot.nodes.contains { node in
                    let label = (node.label ?? "").lowercased()
                    return node.traits.contains(.image)
                        || label.contains("exclamation")
                        || label.contains("triangle")
                        || label == "warning"
                },
                "The warning icon is decorative.\n\(snapshot.debugDescription)"
            )
            XCTAssertEqual(
                log.messages,
                [LaunchFailureAnnouncement.spoken(title: copy.title, message: copy.message)]
            )
        }
    }

    func testLaunchFailureAnnouncementIsAssertive() {
        let title = "Unable to restore your session"
        let message = "We couldn't check whether you're signed in. Check your connection and try again."
        let announcement = LaunchFailureAnnouncement.attributed(title: title, message: message)

        XCTAssertEqual(String(announcement.characters), "\(title). \(message)")
        XCTAssertEqual(announcement.accessibilitySpeechAnnouncementPriority, .high)
    }
}

private final class LaunchAnnouncementLog {
    var messages: [String] = []
}

@MainActor
private struct LaunchFailureAccessibilitySnapshot {
    let nodes: [LaunchFailureAccessibilityNode]

    init(_ view: some View) {
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))

        var collected: [LaunchFailureAccessibilityNode] = []
        var visited: Set<ObjectIdentifier> = []
        if let view = host.view {
            collectLaunchFailureAccessibility(view, into: &collected, visited: &visited)
        }
        nodes = collected
        window.isHidden = true
    }

    var debugDescription: String {
        nodes.map { node in
            "label=\(node.label ?? "-") traits=\(node.traitDescription)"
        }
        .joined(separator: "\n")
    }
}

private struct LaunchFailureAccessibilityNode {
    var label: String?
    var traits: UIAccessibilityTraits

    var traitDescription: String {
        var names: [String] = []
        if traits.contains(.button) { names.append("button") }
        if traits.contains(.image) { names.append("image") }
        if traits.contains(.staticText) { names.append("staticText") }
        if traits.contains(.header) { names.append("header") }
        return names.isEmpty ? String(traits.rawValue) : names.joined(separator: ",")
    }
}

@MainActor
private func collectLaunchFailureAccessibility(
    _ object: Any,
    into nodes: inout [LaunchFailureAccessibilityNode],
    visited: inout Set<ObjectIdentifier>
) {
    guard let accessibility = unwrapLaunchFailureAccessibility(object) else { return }
    let identity = ObjectIdentifier(accessibility)
    guard visited.insert(identity).inserted else { return }
    if accessibility.accessibilityElementsHidden { return }
    if let view = accessibility as? UIView, view.isHidden { return }

    if accessibility.isAccessibilityElement {
        nodes.append(
            LaunchFailureAccessibilityNode(
                label: accessibility.accessibilityLabel,
                traits: accessibility.accessibilityTraits
            )
        )
        return
    }

    if let elements = accessibility.accessibilityElements {
        for element in elements {
            collectLaunchFailureAccessibility(element, into: &nodes, visited: &visited)
        }
        return
    }

    guard let view = accessibility as? UIView else { return }
    let count = view.accessibilityElementCount()
    if count != NSNotFound {
        if count > 0 && count < 200 {
            for index in 0..<count {
                if let element = view.accessibilityElement(at: index) {
                    collectLaunchFailureAccessibility(element, into: &nodes, visited: &visited)
                }
            }
        }
        return
    }
    for subview in view.subviews {
        collectLaunchFailureAccessibility(subview, into: &nodes, visited: &visited)
    }
}

private func unwrapLaunchFailureAccessibility(_ object: Any) -> NSObject? {
    let mirror = Mirror(reflecting: object)
    if mirror.displayStyle == .optional {
        guard let child = mirror.children.first else { return nil }
        return unwrapLaunchFailureAccessibility(child.value)
    }
    return object as? NSObject
}
