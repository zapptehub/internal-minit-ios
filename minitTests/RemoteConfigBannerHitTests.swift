import XCTest
@testable import minit

/// The downtime banner sits in a full-screen overlay window. Start's Get started and
/// Try demo mode must still receive taps. Only the banner cards, including X and Update, claim hits.
@MainActor
final class RemoteConfigBannerHitTests: XCTestCase {
    func testDowntimeBannerDoesNotClaimStartOrDemoTaps() {
        let gate = makeGate(snapshot: bannerSnapshot())
        let decision = gate.decision(languageCode: "en")
        XCTAssertNotNil(decision.downtimeBanner)
        XCTAssertNotNil(decision.softBanner, "installed \(gate.installedMarketingVersion)")
        XCTAssertFalse(decision.coversApp)

        guard let scene = OverlayWindow.foregroundScene else {
            XCTFail("No foreground window scene")
            return
        }
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let coordinator = RemoteConfigWindowAnchor.Coordinator()
        let window = coordinator.installHitTestHarness(
            scene: scene,
            gate: gate,
            locale: Locale(identifier: "en")
        )
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }

        let frames = waitForFrames(in: window)
        XCTAssertEqual(frames.count, 2, "downtime and soft cards should register hit areas, host \(coordinator.hitTestHostFrame)")
        assertPassThrough(frames: frames, window: window, coordinator: coordinator)

        coordinator.expandHostToFillWindowForHitTesting()
        let expanded = waitForFrames(in: window)
        XCTAssertGreaterThan(coordinator.hitTestHostFrame.height, window.bounds.height * 0.9)
        assertPassThrough(frames: expanded, window: window, coordinator: coordinator)

        window.setBlocksTouches(true)
        let below = passThroughPoint(frames: expanded, window: window)
        XCTAssertNotNil(
            window.hitTest(below, with: nil),
            "blocking and force sheets must still take touches outside the banner"
        )
    }

    private func assertPassThrough(
        frames: [CGRect],
        window: OverlayWindow,
        coordinator: RemoteConfigWindowAnchor.Coordinator
    ) {
        XCTAssertFalse(frames.isEmpty)
        let below = passThroughPoint(frames: frames, window: window)
        for frame in frames {
            XCTAssertFalse(frame.contains(below), "banner \(frame) contains Start point \(below)")
            XCTAssertLessThan(frame.maxY, below.y)
            let center = CGPoint(x: frame.midX, y: frame.midY)
            XCTAssertNotNil(window.hitTest(center, with: nil), "card center \(center) host \(coordinator.hitTestHostFrame)")
            let close = CGPoint(x: frame.maxX - 22, y: frame.minY + 22)
            XCTAssertTrue(frame.contains(close))
            XCTAssertNotNil(window.hitTest(close, with: nil), "banner X \(close)")
            let update = CGPoint(x: frame.midX, y: frame.maxY - 24)
            XCTAssertTrue(frame.contains(update))
            XCTAssertNotNil(window.hitTest(update, with: nil), "banner Update \(update)")
        }
        XCTAssertNil(
            window.hitTest(below, with: nil),
            "Start / demo point \(below) was claimed. frames \(frames) host \(coordinator.hitTestHostFrame)"
        )
        let demo = CGPoint(x: below.x, y: min(window.bounds.height - 24, below.y + 48))
        XCTAssertNil(window.hitTest(demo, with: nil), "Try demo point \(demo) was claimed")
    }

    private func passThroughPoint(frames: [CGRect], window: OverlayWindow) -> CGPoint {
        let lowest = frames.map(\.maxY).max() ?? 0
        let y = min(window.bounds.height - 72, max(lowest + 120, window.bounds.height * 0.72))
        return CGPoint(x: window.bounds.midX, y: y)
    }

    private func waitForFrames(in window: OverlayWindow) -> [CGRect] {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            window.layoutIfNeeded()
            let frames = window.hitRegistry.frames(in: window)
            if frames.count >= 2 { return frames }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return window.hitRegistry.frames(in: window)
    }

    private func makeGate(snapshot: RemoteConfigSnapshot) -> RemoteConfigGate {
        let name = "RemoteConfigBannerHitTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return RemoteConfigGate(
            defaults: defaults,
            backend: BannerHitRemoteConfigBackend(snapshot: snapshot)
        )
    }

    private func bannerSnapshot() -> RemoteConfigSnapshot {
        RemoteConfigSnapshot(
            maintenanceBlocking: false,
            maintenanceBlockingMessage: "{}",
            maintenanceBannerMessage: #"{"en":"Down tonight"}"#,
            maintenanceBannerStart: "",
            maintenanceBannerEnd: "",
            minVersionIOS: "",
            softMinVersionIOS: "999.0",
            updateURLIOS: ""
        )
    }
}

@MainActor
private final class BannerHitRemoteConfigBackend: RemoteConfigBackend {
    var snapshot: RemoteConfigSnapshot

    init(snapshot: RemoteConfigSnapshot) {
        self.snapshot = snapshot
    }

    func readSnapshot() -> RemoteConfigSnapshot { snapshot }

    func fetchAndActivate() async throws -> Bool { true }

    func fetchLatest() async throws {}
}
