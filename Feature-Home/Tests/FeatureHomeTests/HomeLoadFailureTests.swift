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
    /// the failure and request Home again. The second request uses the closure
    /// the Retry button calls. While it is in flight the firebase sample's
    /// bell chrome is on screen.
    ///
    /// The button itself is not pressed. A key `UIHostingController` on this
    /// host does not publish the Retry control (no window scene;
    /// `accessibilityElements` exposes the profile and greeting only), so
    /// there is no element to activate.
    func testFailedHomeScreenRequestsHomeOnceAndRetryRequestsAgain() {
        let client = GateSecondHomeClient()
        defer { client.release() }
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
        let inFlight = waitUntil(timeout: 2) {
            client.requests == 2 && !hooks.showsFailure && hooks.bellShown
        }
        XCTAssertTrue(inFlight, "failure shown=\(hooks.showsFailure) requests=\(client.requests) bell=\(hooks.bellShown)")
        client.release()
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

    init(_ view: some View) {
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
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
    }
}

private struct HomeFailureProfileRepository: ProfileRepository {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? { nil }
}

/// First `GET /v1/home` fails immediately. The next one waits until `release`,
/// so a test can read the sample chrome while Retry is in flight.
private final class GateSecondHomeClient: NetworkClient, @unchecked Sendable {
    private let lock = NSLock()
    private var requestCount = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var requests: Int {
        lock.lock()
        defer { lock.unlock() }
        return requestCount
    }

    func release() {
        lock.lock()
        let pending = waiters
        waiters.removeAll()
        lock.unlock()
        pending.forEach { $0.resume() }
    }

    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        if beginRequest() {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                lock.lock()
                waiters.append(continuation)
                lock.unlock()
            }
        }
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

    private func beginRequest() -> Bool {
        lock.lock()
        requestCount += 1
        let shouldWait = requestCount > 1
        lock.unlock()
        return shouldWait
    }
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
