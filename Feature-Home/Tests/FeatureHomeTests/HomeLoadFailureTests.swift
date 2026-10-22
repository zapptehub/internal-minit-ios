import CoreNetworking
import DataProfile
import SwiftUI
import UIKit
import XCTest
@testable import FeatureHome

@MainActor
final class HomeLoadFailureTests: XCTestCase {
    func testCopyMatchesEnglishHungarianAndSlovak() {
        let expected: [String: (title: String, message: String, retry: String)] = [
            "en": (
                "Unable to load Home",
                "We couldn't load Home. Check your connection and try again.",
                "Retry"
            ),
            "hu": (
                "Nem sikerült betölteni a kezdőlapot",
                "Nem sikerült betöltenünk a kezdőlapot. Ellenőrizd az internetkapcsolatodat, majd próbáld újra.",
                "Újrapróbálás"
            ),
            "sk": (
                "Domovskú stránku sa nepodarilo načítať",
                "Nepodarilo sa načítať domovskú stránku. Skontrolujte pripojenie a skúste to znova.",
                "Skúsiť znova"
            ),
        ]

        for (language, copy) in expected {
            let resolved = HomeLoadFailureCopy(locale: Locale(identifier: language))
            XCTAssertEqual(resolved.title, copy.title, language)
            XCTAssertEqual(resolved.message, copy.message, language)
            XCTAssertEqual(resolved.retry, copy.retry, language)
        }
    }

    func testAnnouncementIsAssertive() {
        let title = "Unable to load Home"
        let message = "We couldn't load Home. Check your connection and try again."
        let announcement = HomeLoadFailureAnnouncement.attributed(title: title, message: message)

        XCTAssertEqual(
            String(announcement.characters),
            HomeLoadFailureAnnouncement.spoken(title: title, message: message)
        )
        XCTAssertEqual(announcement.accessibilitySpeechAnnouncementPriority, .high)
    }

    /// The failure view announces the locale's title and message when it appears.
    /// English, Hungarian, and Slovak are the three http-build languages.
    func testFailureViewAnnouncesTheLocalizedCopyWhenItAppears() {
        for language in ["en", "hu", "sk"] {
            let log = HomeFailureAnnouncementLog()
            let locale = Locale(identifier: language)
            let copy = HomeLoadFailureCopy(locale: locale)
            let host = HomeFailureHost(
                HomeLoadFailureView(announce: { title, message in
                    log.messages.append(HomeLoadFailureAnnouncement.spoken(title: title, message: message))
                }, onRetry: {})
                .environment(\.locale, locale)
            )

            let deadline = Date().addingTimeInterval(1)
            while log.messages.isEmpty, Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }

            XCTAssertEqual(
                log.messages,
                [HomeLoadFailureAnnouncement.spoken(title: copy.title, message: copy.message)],
                language
            )
            _ = host
        }
    }

    /// Flipping to the failure must not restart `.task`. A restart would clear
    /// the failure and request Home again. Retry goes through the closure the
    /// failure button calls.
    func testFailedHomeScreenRequestsHomeOnceAndRetryRequestsAgain() {
        let client = CountingHomeClient()
        let hooks = HomeScreenFailureHooks()
        let host = HomeFailureHost(
            HomeScreen(
                userId: "user-1",
                profileRepository: HomeFailureProfileRepository(),
                homeRepository: HttpHomeRepository(client: client),
                networkClient: client,
                apiBaseURL: "https://api.zappte.eu/mock/min",
                onLogOut: {},
                failureHooks: hooks
            )
            .environment(\.locale, Locale(identifier: "en"))
        )

        let appeared = waitUntil(timeout: 2) {
            hooks.showsFailure && client.requests == 1 && !hooks.bellShown
        }
        XCTAssertTrue(appeared, "failure shown=\(hooks.showsFailure) requests=\(client.requests) bell=\(hooks.bellShown)")
        // One turn so a `.task` restart would increment the count. The failure
        // itself is the condition above, not this wait.
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(client.requests, 1)
        XCTAssertTrue(hooks.showsFailure)
        XCTAssertFalse(hooks.bellShown)
        XCTAssertTrue(hooks.isRetryEnabled)

        hooks.retry()
        let retried = waitUntil(timeout: 2) {
            client.requests == 2 && hooks.showsFailure && !hooks.bellShown
        }
        XCTAssertTrue(retried, "failure shown=\(hooks.showsFailure) requests=\(client.requests) bell=\(hooks.bellShown)")
        _ = host
    }

    /// Logout disables Retry on the failure view, in addition to the screen-wide
    /// `.disabled`. The hook reads the flag passed into `HomeLoadFailureView`.
    func testRetryIsDisabledWhileLoggingOut() {
        let client = CountingHomeClient()
        let hooks = HomeScreenFailureHooks()
        let host = HomeFailureHost(
            HomeScreen(
                userId: "user-1",
                profileRepository: HomeFailureProfileRepository(),
                homeRepository: HttpHomeRepository(client: client),
                networkClient: client,
                apiBaseURL: "https://api.zappte.eu/mock/min",
                onLogOut: {},
                failureHooks: hooks
            )
        )

        XCTAssertTrue(waitUntil(timeout: 2) { hooks.showsFailure && hooks.isRetryEnabled })
        let requests = client.requests
        hooks.logOut()
        XCTAssertTrue(waitUntil(timeout: 2) { hooks.showsFailure && !hooks.isRetryEnabled })
        hooks.retry()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        XCTAssertEqual(client.requests, requests)
        XCTAssertFalse(hooks.bellShown)
        _ = host
    }

    /// Header trait, Retry button, and hidden warning icon.
    ///
    /// The host window is attached to a connected `UIWindowScene` when one
    /// exists. This package test host has none (`connectedScenes` is empty),
    /// so the window never joins a scene. On that host
    /// `view.accessibilityElements` is non-nil, `accessibilityElementCount`
    /// is 0, and the subtree walk — including subviews when the elements
    /// array is empty — finds no nodes. That read does not assert the header
    /// trait, the Retry button, or the hidden icon, and it is not coverage
    /// of them.
    ///
    /// What this test does check is a modifier seam that runs when the hosted
    /// view appears. The title modifier applies `.accessibilityAddTraits(.isHeader)`.
    /// The icon modifier applies `.accessibilityHidden(true)`. The retry mark
    /// records that the retry control is the `DSButton`, which is a SwiftUI
    /// `Button`. Those flags are not VoiceOver traits.
    ///
    /// `Mirror` of `body` is also tried for an `AccessibilityTraits` value
    /// containing `.isHeader`. The trait is applied inside the `ScrollView`
    /// builder, which that walk does not invoke, so a miss is not a failure
    /// and is not a passed trait check. A hit would fail the test if the
    /// title modifier had not run.
    func testFailureHeaderRetryAndHiddenIcon() {
        let probe = HomeLoadFailureAccessibilityProbe()
        let locale = Locale(identifier: "en")
        let copy = HomeLoadFailureCopy(locale: locale)
        let host = HomeFailureHost(
            HomeLoadFailureView(
                announce: { _, _ in },
                accessibilityProbe: probe,
                onRetry: {}
            )
            .environment(\.locale, locale)
        )

        let modifiersRan = waitUntil(timeout: 1) {
            probe.titleIsHeader && probe.retryIsButton && probe.iconIsHidden
        }
        XCTAssertTrue(
            modifiersRan,
            "titleHeader=\(probe.titleIsHeader) retryButton=\(probe.retryIsButton) iconHidden=\(probe.iconIsHidden) scenes=\(host.sceneCount)"
        )

        let read = host.accessibilityRead()
        let mirrorSawHeader = homeFailureBodyContainsHeaderTrait(
            HomeLoadFailureView(announce: { _, _ in }, onRetry: {})
        )
        if read.nodes.contains(where: { $0.label == copy.title }) {
            let headers = read.nodes.filter { $0.label == copy.title }
            XCTAssertTrue(headers.allSatisfy { $0.traits.contains(.header) }, read.debugDescription)
        }
        if read.nodes.contains(where: { $0.label == copy.retry }) {
            let retry = read.nodes.filter { $0.label == copy.retry }
            XCTAssertEqual(retry.count, 1, read.debugDescription)
            XCTAssertTrue(retry[0].traits.contains(.button), read.debugDescription)
            XCTAssertFalse(retry[0].traits.contains(.header), read.debugDescription)
        }
        if !read.nodes.isEmpty {
            XCTAssertFalse(
                read.nodes.contains { node in
                    let label = (node.label ?? "").lowercased()
                    return node.traits.contains(.image)
                        || label.contains("exclamation")
                        || label.contains("triangle")
                        || label == "warning"
                },
                "The warning icon is decorative.\n\(read.debugDescription)"
            )
        }

        if mirrorSawHeader {
            XCTAssertTrue(probe.titleIsHeader)
        }
        _ = host
    }
}

/// Polls the main run loop until `condition` is true or `timeout` elapses.
@MainActor
private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    return condition()
}

private final class HomeFailureAnnouncementLog {
    var messages: [String] = []
}

/// Keeps a hosting window alive so `.onAppear` and `.task` run.
@MainActor
private final class HomeFailureHost {
    let window: UIWindow
    let sceneCount: Int
    private let hostingView: UIView

    init(_ view: some View) {
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        sceneCount = scenes.count
        if let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first {
            window.windowScene = scene
        }
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.beginAppearanceTransition(true, animated: false)
        host.endAppearanceTransition()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        self.window = window
        self.hostingView = host.view
    }

    func accessibilityRead() -> HomeFailureAccessibilityRead {
        hostingView.setNeedsLayout()
        hostingView.layoutIfNeeded()
        var nodes: [HomeFailureAccessibilityNode] = []
        var visited: Set<ObjectIdentifier> = []
        collectHomeFailureAccessibility(hostingView, into: &nodes, visited: &visited)
        let count = hostingView.accessibilityElementCount()
        return HomeFailureAccessibilityRead(
            nodes: nodes,
            elementsNil: hostingView.accessibilityElements == nil,
            elementCount: count
        )
    }
}

private struct HomeFailureAccessibilityRead {
    var nodes: [HomeFailureAccessibilityNode]
    var elementsNil: Bool
    var elementCount: Int

    var debugDescription: String {
        let body = nodes.map { node in
            "label=\(node.label ?? "-") traits=\(node.traitDescription)"
        }
        .joined(separator: "\n")
        return "elementsNil=\(elementsNil) elementCount=\(elementCount)\n\(body)"
    }
}

private struct HomeFailureAccessibilityNode {
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
private func collectHomeFailureAccessibility(
    _ object: Any,
    into nodes: inout [HomeFailureAccessibilityNode],
    visited: inout Set<ObjectIdentifier>
) {
    guard let accessibility = unwrapHomeFailureAccessibility(object) else { return }
    let identity = ObjectIdentifier(accessibility)
    guard visited.insert(identity).inserted else { return }
    if accessibility.accessibilityElementsHidden { return }
    if let view = accessibility as? UIView, view.isHidden { return }

    if accessibility.isAccessibilityElement {
        nodes.append(
            HomeFailureAccessibilityNode(
                label: accessibility.accessibilityLabel,
                traits: accessibility.accessibilityTraits
            )
        )
        return
    }

    if let elements = accessibility.accessibilityElements, !elements.isEmpty {
        for element in elements {
            collectHomeFailureAccessibility(element, into: &nodes, visited: &visited)
        }
        return
    }

    guard let view = accessibility as? UIView else { return }
    let count = view.accessibilityElementCount()
    if count != NSNotFound, count > 0, count < 200 {
        for index in 0..<count {
            if let element = view.accessibilityElement(at: index) {
                collectHomeFailureAccessibility(element, into: &nodes, visited: &visited)
            }
        }
        return
    }
    for subview in view.subviews {
        collectHomeFailureAccessibility(subview, into: &nodes, visited: &visited)
    }
}

private func unwrapHomeFailureAccessibility(_ object: Any) -> NSObject? {
    let mirror = Mirror(reflecting: object)
    if mirror.displayStyle == .optional {
        guard let child = mirror.children.first else { return nil }
        return unwrapHomeFailureAccessibility(child.value)
    }
    return object as? NSObject
}

/// Walks `HomeLoadFailureView.body` for an `AccessibilityTraits` value that
/// contains `.isHeader`. Returns false when the modifier stores the trait in
/// a form this walk cannot see. That false result is not a failed trait check.
@MainActor
private func homeFailureBodyContainsHeaderTrait(_ view: HomeLoadFailureView) -> Bool {
    mirrorContainsHeaderTrait(view.body, depth: 0)
}

private func mirrorContainsHeaderTrait(_ value: Any, depth: Int) -> Bool {
    if depth > 6 { return false }
    if let traits = value as? AccessibilityTraits, traits.contains(.isHeader) {
        return true
    }
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional {
        guard let child = mirror.children.first else { return false }
        return mirrorContainsHeaderTrait(child.value, depth: depth + 1)
    }
    for child in mirror.children {
        if mirrorContainsHeaderTrait(child.value, depth: depth + 1) {
            return true
        }
    }
    return false
}

private struct HomeFailureProfileRepository: ProfileRepository {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? { nil }
}

private final class CountingHomeClient: NetworkClient, @unchecked Sendable {
    private let lock = NSLock()
    private var requestCount = 0

    var requests: Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCount
    }

    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        lock.lock()
        requestCount += 1
        lock.unlock()
        throw NetworkError.statusCode(503, Data())
    }

    func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: B
    ) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ url: URL) async throws -> Data {
        throw NetworkError.invalidURL
    }
}
