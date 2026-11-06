import XCTest
@testable import minit

/// The downtime banner sits in a full-screen overlay window. Start's Get started and
/// Try demo mode must still receive taps. Only the banner cards, including X and Update, claim hits.
/// A tester alert presented on that window must take every touch until it is dismissed.
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

    func testSoftUpdateAlertButtonsAreHitUntilDismissed() {
        let gate = makeGate(snapshot: softBannerSnapshot())
        let decision = gate.decision(languageCode: "en")
        XCTAssertNotNil(decision.softBanner)
        XCTAssertFalse(decision.coversApp)

        guard let window = installWindow(gate: gate) else { return }
        defer { hide(window) }

        let frames = waitForFrames(in: window, minimum: 1)
        XCTAssertEqual(frames.count, 1, "soft card should register a hit area")
        let below = passThroughPoint(frames: frames, window: window)
        XCTAssertNil(window.hitTest(below, with: nil), "Start must receive taps before the alert")
        XCTAssertFalse(window.claimsAllTouches)

        let alert = testerAlert(onCancel: {}, onOpenMail: {})
        window.rootViewController?.present(alert, animated: false)
        XCTAssertTrue(waitUntil { window.rootViewController?.presentedViewController === alert })
        XCTAssertTrue(window.claimsAllTouches)
        XCTAssertFalse(window.blocksTouches)

        assertAlertControl("Open mail", in: alert, window: window)
        assertAlertControl("Cancel", in: alert, window: window)
        XCTAssertNotNil(window.hitTest(below, with: nil), "content behind the alert must not receive taps")

        let dismissed = expectation(description: "alert dismissed")
        alert.dismiss(animated: false) { dismissed.fulfill() }
        wait(for: [dismissed], timeout: 2)
        XCTAssertTrue(waitUntil { window.rootViewController?.presentedViewController == nil })
        XCTAssertFalse(window.claimsAllTouches)
        XCTAssertNil(window.hitTest(below, with: nil), "pass-through must return after the alert closes")
        XCTAssertNotNil(window.hitTest(CGPoint(x: frames[0].midX, y: frames[0].midY), with: nil))
    }

    func testBlockingOverlayStillHitsAnAlertAboveTheSheet() {
        let gate = makeGate(snapshot: softBannerSnapshot())
        guard let window = installWindow(gate: gate) else { return }
        defer { hide(window) }

        let frames = waitForFrames(in: window, minimum: 1)
        let below = passThroughPoint(frames: frames, window: window)
        window.setBlocksTouches(true)
        XCTAssertNotNil(window.hitTest(below, with: nil), "force and maintenance sheets take touches outside the banner")

        let alert = testerAlert(onCancel: {}, onOpenMail: {})
        window.rootViewController?.present(alert, animated: false)
        XCTAssertTrue(waitUntil { window.rootViewController?.presentedViewController === alert })
        assertAlertControl("Open mail", in: alert, window: window)
        assertAlertControl("Cancel", in: alert, window: window)

        let dismissed = expectation(description: "sheet alert dismissed")
        alert.dismiss(animated: false) { dismissed.fulfill() }
        wait(for: [dismissed], timeout: 2)
        XCTAssertTrue(waitUntil { window.rootViewController?.presentedViewController == nil })
        XCTAssertNotNil(window.hitTest(below, with: nil), "the sheet must keep blocking after the alert closes")
    }

    private func testerAlert(onCancel: @escaping () -> Void, onOpenMail: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: "Internal test build",
            message: "Testers get the new version by email.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Open mail", style: .default) { _ in onOpenMail() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in onCancel() })
        return alert
    }

    private func assertAlertControl(
        _ title: String,
        in alert: UIAlertController,
        window: OverlayWindow,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let control = waitForControl(titled: title, in: alert, window: window) else {
            XCTFail(
                "\(title) was not on screen. window \(window.bounds) alert \(alert.view.convert(alert.view.bounds, to: window)) inWindow \(alert.view.window === window)\n\(controlDump(in: alert.view))",
                file: file,
                line: line
            )
            return
        }
        let windowPoint = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: window)
        guard let hit = window.hitTest(windowPoint, with: nil) else {
            XCTFail(
                "\(title) at \(windowPoint) passed through. window \(window.bounds) control \(control.convert(control.bounds, to: window))",
                file: file,
                line: line
            )
            return
        }
        let landsOnControl = hit === control || hit.isDescendant(of: control) || control.isDescendant(of: hit)
        XCTAssertTrue(landsOnControl, "\(title) hit \(type(of: hit))", file: file, line: line)
        XCTAssertFalse(hit === window || hit === window.rootViewController?.view, file: file, line: line)
        XCTAssertTrue(
            hit === alert.view || hit.isDescendant(of: alert.view) || control.isDescendant(of: alert.view),
            "\(title) hit \(type(of: hit)) is outside the alert",
            file: file,
            line: line
        )
    }

    private func waitForControl(titled title: String, in alert: UIAlertController, window: UIWindow) -> UIView? {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            alert.view.layoutIfNeeded()
            window.layoutIfNeeded()
            if let control = onScreenControl(titled: title, in: alert.view, window: window) {
                return control
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return onScreenControl(titled: title, in: alert.view, window: window)
    }

    private func onScreenControl(titled title: String, in view: UIView, window: UIWindow) -> UIView? {
        let matches = matchingControls(titled: title, in: view)
        return matches.first { control in
            guard control.window === window else { return false }
            let center = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: window)
            return window.bounds.contains(center)
        }
    }

    private func matchingControls(titled title: String, in view: UIView) -> [UIView] {
        var matches: [UIView] = []
        if controlTitle(view) == title, view.bounds.width > 1, view.bounds.height > 1 {
            matches.append(view)
        }
        for subview in view.subviews {
            matches.append(contentsOf: matchingControls(titled: title, in: subview))
        }
        return matches
    }

    private func controlTitle(_ view: UIView) -> String {
        if let button = view as? UIButton {
            let title = button.configuration?.title ?? button.currentTitle ?? button.titleLabel?.text ?? button.accessibilityLabel ?? ""
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let label = view as? UILabel {
            let title = label.attributedText?.string ?? label.text ?? ""
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return view.accessibilityLabel?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func controlDump(in view: UIView) -> String {
        var lines: [String] = []
        func walk(_ view: UIView, _ depth: Int) {
            guard lines.count < 30 else { return }
            let center = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: view.window)
            lines.append(
                "\(String(repeating: " ", count: depth))\(type(of: view)) \(controlTitle(view)) center \(center) window \(view.window != nil)"
            )
            view.subviews.forEach { walk($0, depth + 1) }
        }
        walk(view, 0)
        return lines.joined(separator: "\n")
    }

    private func installWindow(gate: RemoteConfigGate) -> OverlayWindow? {
        guard let scene = OverlayWindow.foregroundScene else {
            XCTFail("No foreground window scene")
            return nil
        }
        installedWindow = (
            coordinator: RemoteConfigWindowAnchor.Coordinator(),
            previousKey: scene.windows.first { $0.isKeyWindow }
        )
        let window = installedWindow!.coordinator.installHitTestHarness(
            scene: scene,
            gate: gate,
            locale: Locale(identifier: "en")
        )
        window.makeKeyAndVisible()
        return window
    }

    private var installedWindow: (coordinator: RemoteConfigWindowAnchor.Coordinator, previousKey: UIWindow?)?

    private func hide(_ window: OverlayWindow) {
        window.isHidden = true
        window.rootViewController?.dismiss(animated: false)
        window.rootViewController = nil
        installedWindow?.previousKey?.makeKey()
        installedWindow = nil
    }

    private func waitUntil(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        return condition()
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

    private func waitForFrames(in window: OverlayWindow, minimum: Int = 2) -> [CGRect] {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            window.layoutIfNeeded()
            let frames = window.hitRegistry.frames(in: window)
            if frames.count >= minimum { return frames }
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

    private func softBannerSnapshot() -> RemoteConfigSnapshot {
        RemoteConfigSnapshot(
            maintenanceBlocking: false,
            maintenanceBlockingMessage: "{}",
            maintenanceBannerMessage: "{}",
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
