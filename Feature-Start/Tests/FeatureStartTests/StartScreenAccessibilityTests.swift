import SwiftUI
import UIKit
import XCTest
@testable import FeatureStart

@MainActor
final class StartScreenAccessibilityTests: XCTestCase {
    func testHeroImageIsHiddenFromVoiceOver() {
        let snapshot = StartAccessibilitySnapshot(
            StartScreen(analytics: nil, onGetStarted: {})
                .environment(\.locale, Locale(identifier: "en"))
        )

        XCTAssertTrue(
            snapshot.contains(label: "Get started"),
            "Expected the hosted Start screen accessibility tree to include Get started.\n\(snapshot.debugDescription)"
        )
        XCTAssertFalse(
            snapshot.containsStartHero,
            "The decorative hero must not be exposed as Image/StartHero.\n\(snapshot.debugDescription)"
        )
        XCTAssertFalse(
            snapshot.containsImageElement,
            "Start has no informative image; the hero and logo are decorative.\n\(snapshot.debugDescription)"
        )
    }

    func testHeadlineIsAHeaderAndTheActionIsNot() {
        let snapshot = StartAccessibilitySnapshot(
            StartScreen(analytics: nil, onGetStarted: {})
                .environment(\.locale, Locale(identifier: "en"))
        )

        let headlines = snapshot.nodes.filter { node in
            let label = (node.label ?? "").replacingOccurrences(of: "\n", with: " ")
            return label.contains("Make your") && label.contains("day better")
        }
        XCTAssertEqual(headlines.count, 1, snapshot.debugDescription)
        XCTAssertTrue(headlines[0].traits.contains(.header), snapshot.debugDescription)

        let action = snapshot.nodes.filter { $0.label == "Get started" }
        XCTAssertEqual(action.count, 1, snapshot.debugDescription)
        XCTAssertFalse(action[0].traits.contains(.header), snapshot.debugDescription)
    }
}

@MainActor
private struct StartAccessibilitySnapshot {
    let nodes: [StartAccessibilityNode]

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

        var collected: [StartAccessibilityNode] = []
        var visited: Set<ObjectIdentifier> = []
        if let view = host.view {
            collectStartAccessibility(view, into: &collected, visited: &visited)
        }
        nodes = collected
        window.isHidden = true
    }

    func contains(label: String) -> Bool {
        nodes.contains { $0.label == label }
    }

    var containsStartHero: Bool {
        nodes.contains { node in
            [node.label, node.value, node.hint, node.identifier].contains { text in
                text?.localizedCaseInsensitiveContains("StartHero") == true
            }
        }
    }

    var containsImageElement: Bool {
        nodes.contains { $0.traits.contains(.image) }
    }

    var debugDescription: String {
        nodes.map { node in
            "label=\(node.label ?? "-") value=\(node.value ?? "-") hint=\(node.hint ?? "-") id=\(node.identifier ?? "-") traits=\(node.traitDescription)"
        }
        .joined(separator: "\n")
    }
}

private struct StartAccessibilityNode {
    var label: String?
    var value: String?
    var hint: String?
    var identifier: String?
    var traits: UIAccessibilityTraits

    var traitDescription: String {
        var names: [String] = []
        if traits.contains(.button) { names.append("button") }
        if traits.contains(.image) { names.append("image") }
        if traits.contains(.staticText) { names.append("staticText") }
        if traits.contains(.link) { names.append("link") }
        if traits.contains(.header) { names.append("header") }
        return names.isEmpty ? String(traits.rawValue) : names.joined(separator: ",")
    }
}

@MainActor
private func collectStartAccessibility(
    _ object: Any,
    into nodes: inout [StartAccessibilityNode],
    visited: inout Set<ObjectIdentifier>
) {
    guard let accessibility = unwrapAccessibilityObject(object) else { return }
    let identity = ObjectIdentifier(accessibility)
    guard visited.insert(identity).inserted else { return }
    if accessibility.accessibilityElementsHidden { return }
    if let view = accessibility as? UIView, view.isHidden { return }

    if accessibility.isAccessibilityElement {
        nodes.append(
            StartAccessibilityNode(
                label: accessibility.accessibilityLabel,
                value: accessibility.accessibilityValue,
                hint: accessibility.accessibilityHint,
                identifier: (accessibility as? UIAccessibilityIdentification)?.accessibilityIdentifier,
                traits: accessibility.accessibilityTraits
            )
        )
        return
    }

    if let elements = accessibility.accessibilityElements {
        for element in elements {
            collectStartAccessibility(element, into: &nodes, visited: &visited)
        }
        return
    }

    guard let view = accessibility as? UIView else { return }
    let count = view.accessibilityElementCount()
    if count != NSNotFound {
        if count > 0 && count < 200 {
            for index in 0..<count {
                if let element = view.accessibilityElement(at: index) {
                    collectStartAccessibility(element, into: &nodes, visited: &visited)
                }
            }
        }
        return
    }
    for subview in view.subviews {
        collectStartAccessibility(subview, into: &nodes, visited: &visited)
    }
}

/// `accessibilityElement(at:)` can hand back a nested optional that does not
/// bridge to the underlying accessibility object.
private func unwrapAccessibilityObject(_ object: Any) -> NSObject? {
    let mirror = Mirror(reflecting: object)
    if mirror.displayStyle == .optional {
        guard let child = mirror.children.first else { return nil }
        return unwrapAccessibilityObject(child.value)
    }
    return object as? NSObject
}
