import CoreLogging
import CoreNetworking
import DesignSystem
import ObjectiveC
import SwiftUI
import UIKit
import XCTest
@testable import minit

#if MINIT_SHAKE
final class ShakeReportTests: XCTestCase {
    override func tearDown() {
        ShakeReportLog.shared.endSession()
        ShakeReportLog.shared.setEnabled(false)
        DiagnosticLines.record = nil
        ShakeReportTouches.resetForTests()
        super.tearDown()
    }

    func testGateTreatsEmptyMissingAndUnexpandedAsOff() {
        XCTAssertNil(ShakeReportGate.address(from: nil))
        XCTAssertNil(ShakeReportGate.address(from: ""))
        XCTAssertNil(ShakeReportGate.address(from: "   "))
        XCTAssertNil(ShakeReportGate.address(from: "$(MINIT_SHAKE_REPORT_EMAIL)"))
        XCTAssertNil(ShakeReportGate.address(from: "$(OTHER)"))
        XCTAssertEqual(ShakeReportGate.address(from: " qa@example.com "), "qa@example.com")
    }

    func testShakeStaysClosedWhileBusyOrInsideCooldown() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(ShakeReportGate.shouldOpen(
            address: nil,
            busy: false,
            now: now,
            lastShake: now.addingTimeInterval(-2)
        ))
        XCTAssertFalse(ShakeReportGate.shouldOpen(
            address: "qa@example.com",
            busy: true,
            now: now,
            lastShake: now.addingTimeInterval(-2)
        ))
        XCTAssertFalse(ShakeReportGate.shouldOpen(
            address: "qa@example.com",
            busy: false,
            now: now,
            lastShake: now.addingTimeInterval(-1)
        ))
        XCTAssertFalse(ShakeReportGate.shouldOpen(
            address: "qa@example.com",
            busy: false,
            now: now,
            lastShake: now.addingTimeInterval(-1.99)
        ))
        XCTAssertTrue(ShakeReportGate.shouldOpen(
            address: "qa@example.com",
            busy: false,
            now: now,
            lastShake: now.addingTimeInterval(-2)
        ))
    }

    func testShakeOpensWhenTheClockMovesBackwards() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(ShakeReportGate.shouldOpen(
            address: "qa@example.com",
            busy: false,
            now: now,
            lastShake: now.addingTimeInterval(1)
        ))
        XCTAssertFalse(ShakeReportGate.shouldOpen(
            address: "qa@example.com",
            busy: true,
            now: now,
            lastShake: now.addingTimeInterval(1)
        ))
        XCTAssertFalse(ShakeReportGate.shouldOpen(
            address: nil,
            busy: false,
            now: now,
            lastShake: now.addingTimeInterval(1)
        ))
    }

    func testScrubDropsSecretsAndHeaderKeepsUidAndEmail() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.signaturevalue"
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let log = ShakeReportLog(clock: { clock.now })
        log.beginGetStarted()
        log.record(
            "Authorization: Bearer \(jwt) Cookie: sid=cookie-secret CF-Access-Client-Secret: cf-secret-value Bearer super-secret-token GET /v1/loyalty-cards/MINIT-CONTRACT1/claim?token=abc&password=pw&secret=sec&ok=1 200 12ms"
        )
        let text = log.render(
            description: "the screen froze",
            context: sampleContext(),
            identity: ShakeReportIdentity(uid: "uid-full-123", email: "qa@example.com")
        )

        XCTAssertTrue(text.contains("uid: uid-full-123"))
        XCTAssertTrue(text.contains("email: qa@example.com"))
        XCTAssertTrue(text.contains("the screen froze"))
        XCTAssertTrue(text.contains("/v1/loyalty-cards/[redacted]/claim"))
        XCTAssertTrue(text.contains("ok=1"))
        XCTAssertFalse(text.contains("MINIT-CONTRACT1"))
        XCTAssertFalse(text.contains(jwt))
        XCTAssertFalse(text.contains("super-secret-token"))
        XCTAssertFalse(text.contains("cf-secret-value"))
        XCTAssertFalse(text.contains("cookie-secret"))
        XCTAssertFalse(text.contains("token="))
        XCTAssertFalse(text.contains("password="))
        XCTAssertFalse(text.contains("secret="))
        assertEventLinesAreStamped(text)
    }

    func testLocalClockPrefixesLinesAndHeaderStaysUTC() {
        let zone = TimeZone(secondsFromGMT: 2 * 60 * 60)!
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        utc.locale = Locale(identifier: "en_US_POSIX")
        let origin = utc.date(from: DateComponents(
            year: 2026, month: 10, day: 29, hour: 19, minute: 44, second: 18, nanosecond: 123_000_000
        ))!
        XCTAssertEqual(ShakeReportTime.localClock(origin, timeZone: zone), "21:44:18.123")
        XCTAssertEqual(ShakeReportTime.text(origin), "2026-10-29T19:44:18Z")

        let morning = utc.date(from: DateComponents(
            year: 2026, month: 1, day: 2, hour: 23, minute: 5, second: 6, nanosecond: 7_000_000
        ))!
        XCTAssertEqual(ShakeReportTime.localClock(morning, timeZone: zone), "01:05:06.007")
        let almostNext = utc.date(from: DateComponents(
            year: 2026, month: 1, day: 2, hour: 23, minute: 5, second: 6, nanosecond: 999_000_000
        ))!
        XCTAssertEqual(
            ShakeReportTime.localClock(almostNext, timeZone: TimeZone(secondsFromGMT: 0)!),
            "23:05:06.999"
        )

        let clock = TestClock(origin)
        let log = ShakeReportLog(clock: { clock.now }, timeZone: { zone })
        log.beginGetStarted()
        log.record("start.demo.continue")
        clock.advance(6 * 60)
        log.record("kept-line")

        let text = log.render(description: "plain note", context: sampleContext(), identity: nil)
        let parts = text.components(separatedBy: "\n\n")
        XCTAssertEqual(parts[1], "plain note")
        XCTAssertTrue(parts[0].contains("session_start: 2026-10-29T19:44:18Z"))
        XCTAssertTrue(parts[0].contains("window_start: 2026-10-29T19:44:18Z"))
        XCTAssertTrue(parts[0].contains("tz: +02:00"))
        XCTAssertFalse(parts[0].contains("21:44:18.123"))
        XCTAssertTrue(parts[2].contains("21:44:18.123 start.demo.continue"))
        let kept = ShakeReportTime.localClock(origin.addingTimeInterval(6 * 60), timeZone: zone)
        XCTAssertTrue(parts[2].contains("\(kept) kept-line"))
        assertEventLinesAreStamped(text)
    }

    func testNewlineInARecordedLineStaysOneStampedLine() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let zone = TimeZone(secondsFromGMT: 0)!
        let log = ShakeReportLog(clock: { clock.now }, timeZone: { zone })
        log.beginGetStarted()
        log.record("alpha\r\nbeta\ngamma\rdelta")
        XCTAssertEqual(log.storedLineTexts(), ["alpha beta gamma delta"])
        let text = log.render(description: "note", context: sampleContext(), identity: nil)
        let stamp = ShakeReportTime.localClock(clock.now, timeZone: zone)
        XCTAssertTrue(text.contains("\(stamp) alpha beta gamma delta"))
        assertEventLinesAreStamped(text)
    }

    func testDisabledLogRecordsNothing() {
        let log = ShakeReportLog(enabled: false)
        log.beginGetStarted()
        log.record("hidden\nline")
        XCTAssertTrue(log.storedLineTexts().isEmpty)
        let text = log.render(description: "note", context: sampleContext(), identity: nil)
        XCTAssertFalse(text.contains("hidden"))
        XCTAssertTrue(text.contains("session: none"))
        XCTAssertTrue(text.contains("entry: none"))
    }

    func testTapNamesPreferIdentifiersAndNeverIncludeSecrets() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.signaturevalue"
        let cases: [(ShakeReportTapTarget, String?)] = [
            (ShakeReportTapTarget(identifier: "home.notifications", label: "Iveta", role: .button, interactive: true), "home.notifications"),
            (ShakeReportTapTarget(identifier: "email", label: "qa@example.com", role: .field, isTextInput: true, interactive: true), "field.email"),
            (ShakeReportTapTarget(label: "qa@example.com", role: .field, isTextInput: true, interactive: true), "field"),
            (ShakeReportTapTarget(label: "+421901234567", role: .button, interactive: true), "button"),
            (ShakeReportTapTarget(label: jwt, role: .button, interactive: true), "button"),
            (ShakeReportTapTarget(identifier: "uid-full-123", label: "Iveta", role: .card, interactive: true), "card"),
            (ShakeReportTapTarget(identifier: "home.news.item", label: "Iveta", role: .card, interactive: true), "home.news.item"),
            (ShakeReportTapTarget(label: "Iveta", role: .row, interactive: true), "row"),
            (ShakeReportTapTarget(label: "Iveta", role: .card, interactive: true), "card"),
            (ShakeReportTapTarget(identifier: "marketing", role: .toggle, interactive: true), "toggle.marketing"),
            (ShakeReportTapTarget(role: .toggle, interactive: true), "toggle"),
            (ShakeReportTapTarget(label: "Report", role: .alert, interactive: true), "alert.report"),
            (ShakeReportTapTarget(label: "Cancel", role: .alert, interactive: true), "alert.cancel"),
            (ShakeReportTapTarget(label: "Send", role: .button, inSheet: true, interactive: true), "sheet.send"),
            (ShakeReportTapTarget(identifier: "shake.report.send", label: "Send", role: .button, inSheet: true, interactive: true), "shake.report.send"),
            (ShakeReportTapTarget(label: "Back", role: .button, interactive: true), "back"),
            (ShakeReportTapTarget(label: "Späť", role: .button, interactive: true), "back"),
            (ShakeReportTapTarget(label: "Vissza", role: .button, interactive: true), "back"),
            (ShakeReportTapTarget(identifier: "BackButton", role: .button, interactive: true), "back"),
            (ShakeReportTapTarget(label: "Back to Login", role: .button, interactive: true), "button"),
            (ShakeReportTapTarget(label: "Iveta", role: .button, interactive: true), "button"),
            (ShakeReportTapTarget(label: "Would you like to report a bug about Iveta?", role: .alert, interactive: true), "alert"),
            (ShakeReportTapTarget(label: "Good evening Iveta", role: .control, interactive: false), nil),
            (ShakeReportTapTarget(label: "q", role: .button, isKeyboard: true, interactive: true), nil),
            (ShakeReportTapTarget(role: .button, interactive: true), "button"),
            (ShakeReportTapTarget(role: .row, interactive: true), "row"),
            (ShakeReportTapTarget(role: .card, interactive: true), "card"),
        ]
        for (target, expected) in cases {
            let name = ShakeReportTapNaming.name(for: target)
            XCTAssertEqual(name, expected, "\(target)")
            let blob = name ?? ""
            XCTAssertFalse(blob.contains("Iveta"), blob)
            XCTAssertFalse(blob.contains("@"), blob)
            XCTAssertFalse(blob.contains("421"), blob)
            XCTAssertFalse(blob.contains("eyJ"), blob)
            XCTAssertFalse(blob.contains("uid-full"), blob)
        }

        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let log = ShakeReportLog(clock: { clock.now }, timeZone: { TimeZone(secondsFromGMT: 0)! })
        log.beginGetStarted()
        log.record("tap alert Bearer super-secret-token")
        let text = log.render(description: "note", context: sampleContext(), identity: nil)
        let stamp = ShakeReportTime.localClock(clock.now, timeZone: TimeZone(secondsFromGMT: 0)!)
        XCTAssertTrue(text.contains("\(stamp) tap alert Bearer [redacted]"))
        XCTAssertFalse(text.contains("super-secret-token"))
        assertEventLinesAreStamped(text)
    }

    func testTabChangesUseStableIDs() {
        XCTAssertEqual(DiagnosticTaps.tab("offers"), "tap tab.offers")
        XCTAssertEqual(DiagnosticTaps.tab("home"), "tap tab.home")
        XCTAssertEqual(DiagnosticTaps.tab("tab.map"), "tap tab.map")
        XCTAssertEqual(DiagnosticTaps.tab("qa@example.com"), "tap tab")
        XCTAssertEqual(DiagnosticTaps.tab("uid-full-123"), "tap tab")
        XCTAssertEqual(DiagnosticTaps.tab("secret-user"), "tap tab")

        let keys = [
            ("common.tabName.home", "home"),
            ("common.tabName.offers", "offers"),
            ("common.tabName.map", "map"),
            ("common.tabName.card", "card"),
            ("common.tabName.game", "game"),
        ]
        for language in ["en", "sk", "hu"] {
            for (key, id) in keys {
                let title = DesignSystemLocalizedString.string(key, locale: Locale(identifier: language))
                XCTAssertEqual(DiagnosticTaps.tabID(matchingTitle: title), id, "\(language) \(title)")
                let named = ShakeReportTapNaming.name(
                    for: ShakeReportTapTarget(label: title, role: .tab, interactive: true)
                )
                XCTAssertEqual(named, "tab.\(id)", "\(language) \(title)")
            }
        }

        let offers = ShakeReportTapNaming.name(
            for: ShakeReportTapTarget(identifier: "tab.offers", label: "Ponuky", role: .tab, interactive: true)
        )
        XCTAssertEqual(offers, "tab.offers")
        let unknown = ShakeReportTapNaming.name(
            for: ShakeReportTapTarget(label: "qa@example.com", role: .tab, interactive: true)
        )
        XCTAssertEqual(unknown, "tab")
    }

    func testCapturedTapsUseTheControlNotItsContents() {
        let identified = UIButton(type: .system)
        identified.accessibilityIdentifier = "home.notifications"
        identified.setTitle("qa@example.com", for: .normal)
        identified.accessibilityLabel = "Iveta"
        XCTAssertEqual(tapName(for: identified), "home.notifications")

        let emailButton = UIButton(type: .system)
        emailButton.setTitle("qa@example.com", for: .normal)
        XCTAssertEqual(tapName(for: emailButton), "button")

        let field = UITextField()
        field.accessibilityIdentifier = "email"
        field.text = "qa@example.com"
        field.accessibilityLabel = "qa@example.com"
        XCTAssertEqual(tapName(for: field), "field.email")

        let secretField = UITextField()
        secretField.text = "+421901234567"
        secretField.accessibilityLabel = "+421901234567"
        XCTAssertEqual(tapName(for: secretField), "field")

        let key = UIButton(type: .system)
        key.accessibilityTraits.insert(.keyboardKey)
        key.setTitle("q", for: .normal)
        key.accessibilityLabel = "q"
        XCTAssertNil(tapName(for: key))

        let greeting = UILabel()
        greeting.text = "Good evening Iveta"
        greeting.accessibilityLabel = "Good evening Iveta"
        XCTAssertNil(tapName(for: greeting))

        let row = UITableViewCell()
        row.textLabel?.text = "Iveta"
        row.accessibilityLabel = "Iveta"
        XCTAssertEqual(tapName(for: row), "row")

        let card = ShakeReportCardCell()
        card.accessibilityLabel = "Iveta"
        XCTAssertEqual(tapName(for: card), "card")

        let toggle = UISwitch()
        toggle.accessibilityIdentifier = "marketing"
        XCTAssertEqual(tapName(for: toggle), "toggle.marketing")

        let alert = UIAlertController(title: "Shake detected", message: "Would you like to report a bug?", preferredStyle: .alert)
        let alertButton = UIButton(type: .system)
        alertButton.accessibilityLabel = "Report"
        alert.view.addSubview(alertButton)
        XCTAssertEqual(tapName(for: alertButton), "alert.report")

        let sheetWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let presenter = UIViewController()
        sheetWindow.rootViewController = presenter
        sheetWindow.makeKeyAndVisible()
        let sheet = UIViewController()
        sheet.modalPresentationStyle = .pageSheet
        presenter.present(sheet, animated: false)
        let send = UIButton(type: .system)
        send.setTitle("Send", for: .normal)
        send.accessibilityLabel = "Send"
        sheet.view.addSubview(send)
        XCTAssertEqual(tapName(for: send), "sheet.send")
        sheetWindow.isHidden = true

        let person = UIButton(type: .system)
        person.setTitle("Iveta", for: .normal)
        XCTAssertEqual(tapName(for: person), "button")

        let message = UILabel()
        message.accessibilityLabel = "Would you like to report a bug about Iveta?"
        alert.view.addSubview(message)
        XCTAssertEqual(tapName(for: message), "alert")
        XCTAssertFalse(tapName(for: message)?.contains("Iveta") ?? true)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let nav = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = nav
        window.makeKeyAndVisible()
        nav.pushViewController(UIViewController(), animated: false)
        let back = UIButton(type: .custom)
        back.accessibilityLabel = "qa@example.com"
        back.frame = CGRect(x: 0, y: 0, width: 80, height: 44)
        nav.navigationBar.addSubview(back)
        XCTAssertEqual(tapName(for: back), "back")
        XCTAssertFalse(tapName(for: back)?.contains("@") ?? true)

        let done = UIButton(type: .custom)
        done.accessibilityLabel = "Done"
        done.frame = CGRect(x: 240, y: 0, width: 80, height: 44)
        nav.navigationBar.addSubview(done)
        nav.navigationBar.accessibilityIdentifier = "UIView"
        XCTAssertEqual(tapName(for: done), "button.done")

        let rootNav = UINavigationController(rootViewController: UIViewController())
        let rootWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        rootWindow.rootViewController = rootNav
        rootWindow.makeKeyAndVisible()
        let close = UIButton(type: .custom)
        close.accessibilityLabel = "Close"
        close.frame = CGRect(x: 0, y: 0, width: 80, height: 44)
        rootNav.navigationBar.addSubview(close)
        XCTAssertEqual(tapName(for: close), "button.close")
        let profile = UIButton(type: .custom)
        profile.accessibilityLabel = "Iveta"
        profile.frame = CGRect(x: 4, y: 0, width: 44, height: 44)
        rootNav.navigationBar.addSubview(profile)
        XCTAssertEqual(tapName(for: profile), "button")

        let bare = UINavigationBar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        let bareLeading = UIButton(type: .custom)
        bareLeading.accessibilityLabel = "qa@example.com"
        bareLeading.frame = CGRect(x: 0, y: 0, width: 80, height: 44)
        bare.addSubview(bareLeading)
        XCTAssertEqual(tapName(for: bareLeading), "button")

        let plainHost = ToggleCardHostingView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        plainHost.isAccessibilityElement = true
        plainHost.accessibilityTraits.insert(.button)
        XCTAssertEqual(tapName(for: plainHost), "button")

        let backHost = ToggleCardHostingView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        backHost.isAccessibilityElement = true
        backHost.accessibilityIdentifier = "back"
        XCTAssertEqual(tapName(for: backHost), "back")

        let closeHost = ToggleCardHostingView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        closeHost.isAccessibilityElement = true
        closeHost.accessibilityIdentifier = "close"
        closeHost.accessibilityLabel = "Zavrieť"
        XCTAssertEqual(tapName(for: closeHost), "close")
        XCTAssertFalse(tapName(for: closeHost)?.contains("Zavrie") ?? true)

        let hostView = ToggleCardHostingView(frame: CGRect(x: 0, y: 0, width: 120, height: 44))
        let hosted = UIButton(type: .system)
        hosted.accessibilityIdentifier = "notify"
        hosted.setTitle("Iveta", for: .normal)
        hostView.addSubview(hosted)
        XCTAssertEqual(tapName(for: hosted), "button.notify")
        XCTAssertNil(tapName(for: hostView))

        let keyboardHost = KeyboardAvoidingPane(frame: hostView.frame)
        let keyed = UIButton(type: .system)
        keyed.accessibilityIdentifier = "notify"
        keyboardHost.addSubview(keyed)
        XCTAssertEqual(tapName(for: keyed), "button.notify")
        XCTAssertFalse(ShakeReportTapCapture.isKeyboardClass(NSStringFromClass(KeyboardAvoidingPane.self)))
        XCTAssertTrue(ShakeReportTapCapture.isKeyboardClass("UITextEffectsWindow"))
        XCTAssertTrue(ShakeReportTapCapture.isKeyboardClass("UIKeyboardImpl"))
        XCTAssertFalse(ShakeReportTapCapture.isKeyboardClass("_TtGC7SwiftUI14_UIHostingViewKeyboardAvoiding"))

        let slovakBack = UIButton(type: .system)
        slovakBack.accessibilityLabel = "Späť"
        XCTAssertEqual(tapName(for: slovakBack), "back")

        window.isHidden = true
        rootWindow.isHidden = true
    }

    func testSameTabRetapUsesStableID() {
        let bar = UITabBar(frame: CGRect(x: 0, y: 0, width: 390, height: 49))
        let home = UITabBarItem(title: "Home", image: nil, tag: 0)
        let offers = UITabBarItem(title: "Ponuky", image: nil, tag: 1)
        bar.items = [home, offers]
        bar.selectedItem = offers

        // iOS 27 draws items in a private platter, not UITabBarButton. The hook matches the
        // item title on the hit view, which is what a platter label exposes.
        let offersHit = UIView(frame: CGRect(x: 200, y: 0, width: 80, height: 49))
        offersHit.isAccessibilityElement = true
        offersHit.accessibilityLabel = "Ponuky"
        let homeHit = UIView(frame: CGRect(x: 20, y: 0, width: 80, height: 49))
        homeHit.isAccessibilityElement = true
        homeHit.accessibilityLabel = "Home"
        bar.addSubview(offersHit)
        bar.addSubview(homeHit)

        XCTAssertEqual(ShakeReportTouches.sameTabRetapName(for: offersHit), "tab.offers")
        XCTAssertNil(ShakeReportTouches.sameTabRetapName(for: homeHit))
        XCTAssertFalse(ShakeReportTouches.sameTabRetapName(for: offersHit)?.contains("Ponuky") ?? true)

        let secretBar = UITabBar(frame: CGRect(x: 0, y: 0, width: 390, height: 49))
        let secret = UITabBarItem(title: "qa@example.com", image: nil, tag: 0)
        secretBar.items = [secret]
        secretBar.selectedItem = secret
        let secretHit = UIView(frame: secretBar.bounds)
        secretHit.isAccessibilityElement = true
        secretHit.accessibilityLabel = "qa@example.com"
        secretBar.addSubview(secretHit)
        XCTAssertEqual(ShakeReportTouches.sameTabRetapName(for: secretHit), "tab")
        XCTAssertFalse(ShakeReportTouches.sameTabRetapName(for: secretHit)?.contains("@") ?? true)
    }

    func testNavigationPopLogsBackOnlyForTheTouchThatPops() {
        let log = ShakeReportLog.shared
        log.setEnabled(true)
        log.endSession()
        log.beginGetStarted()
        ShakeReportHooks.install()
        ShakeReportTouches.resetForTests()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let nav = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = nav
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let detail = UIViewController()
        detail.title = "qa@example.com"
        nav.pushViewController(detail, animated: false)
        let named = UIViewController()
        named.title = "Iveta"
        nav.pushViewController(named, animated: false)

        nav.popViewController(animated: false)
        XCTAssertEqual(backLines(in: log), 0, "a pop outside a touch is not a tap")

        ShakeReportTouches.beginDelivery()
        nav.popViewController(animated: false)
        ShakeReportTouches.endDelivery()
        XCTAssertEqual(backLines(in: log), 1, "a pop inside the touch logs tap back")
        nav.popViewController(animated: false)
        XCTAssertEqual(backLines(in: log), 1)

        nav.pushViewController(UIViewController(), animated: false)
        let back = UIButton(type: .custom)
        back.accessibilityLabel = "qa@example.com"
        back.frame = CGRect(x: 0, y: 0, width: 80, height: 44)
        nav.navigationBar.addSubview(back)
        let point = back.convert(CGPoint(x: 10, y: 10), to: window)
        ShakeReportTouches.beginDelivery()
        nav.popViewController(animated: false)
        ShakeReportTouches.recordHit(back, at: point, in: window)
        ShakeReportTouches.endDelivery()
        XCTAssertEqual(backLines(in: log), 2, "the back button and the pop share one line")

        let joined = log.storedLineTexts().joined(separator: "\n")
        XCTAssertFalse(joined.contains("qa@example.com"))
        XCTAssertFalse(joined.contains("Iveta"))

        ShakeReportTouches.resetForTests()
        let beforeSwipe = backLines(in: log)
        ShakeReportTouches.interactiveBackFinished(cancelled: true)
        XCTAssertEqual(backLines(in: log), beforeSwipe)
        ShakeReportTouches.interactiveBackFinished(cancelled: false)
        XCTAssertEqual(backLines(in: log), beforeSwipe + 1)
        ShakeReportTouches.interactiveBackFinished(cancelled: false)
        XCTAssertEqual(backLines(in: log), beforeSwipe + 1)

        let text = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertNotNil(text.range(of: #"\d{2}:\d{2}:\d{2}\.\d{3} tap back"#, options: .regularExpression))
        assertEventLinesAreStamped(text)
    }

    func testManualControlLineSuppressesTheAutomaticTap() {
        let log = ShakeReportLog.shared
        log.setEnabled(true)
        log.endSession()
        log.beginGetStarted()
        DiagnosticLines.record = { log.record($0) }
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = "home.notifications"
        button.setTitle("Iveta", for: .normal)
        ShakeReportTouches.beginDelivery()
        DiagnosticLines.line("home.notifications")
        ShakeReportTouches.recordHit(button, at: .zero, in: nil)
        ShakeReportTouches.endDelivery()
        XCTAssertEqual(log.storedLineTexts(), ["home.notifications"])
    }

    func testProgrammaticTabChangeLogsRouteOnly() {
        DiagnosticTaps.clearUserTabTap()
        let log = ShakeReportLog.shared
        log.setEnabled(true)
        log.endSession()
        log.beginGetStarted()
        DiagnosticLines.record = { log.record($0) }
        DiagnosticTaps.logSelectionChange("offers")
        XCTAssertEqual(log.storedLineTexts(), ["route tab offers"])
        DiagnosticTaps.noteUserTabTap()
        DiagnosticTaps.logSelectionChange("map")
        XCTAssertEqual(log.storedLineTexts(), ["route tab offers"])
        DiagnosticTaps.logSelectionChange("qa@example.com")
        XCTAssertFalse(log.storedLineTexts().joined(separator: "\n").contains("@"))
        DiagnosticTaps.noteUserTabTap(logsName: false)
        DiagnosticTaps.logSelectionChange("card")
        XCTAssertEqual(
            log.storedLineTexts(),
            ["route tab offers", "tap tab.card"],
            "a touch the hook could not name still records the tab id"
        )
        DiagnosticTaps.logSelectionChange("game")
        XCTAssertEqual(log.storedLineTexts().last, "route tab game")
        XCTAssertFalse(ShakeReportTapCapture.isStationary(moved: 10, tapCount: 1))
        XCTAssertFalse(ShakeReportTapCapture.isStationary(moved: 24, tapCount: 1))
        XCTAssertTrue(ShakeReportTapCapture.isStationary(moved: 9, tapCount: 1))
        XCTAssertFalse(ShakeReportTapCapture.isStationary(moved: 0, tapCount: 0))
    }

    func testGetStartedWindowCutsToTwentyMinutes() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let origin = clock.now
        let log = ShakeReportLog(clock: { clock.now })
        log.beginGetStarted()
        log.record("early-line")
        clock.advance(6 * 60)
        log.record("kept-line")
        clock.advance(19 * 60)
        log.record("late-line")

        let text = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertTrue(text.contains("entry: get_started"))
        XCTAssertTrue(text.contains("cut_by_20min: true"))
        XCTAssertTrue(text.contains("window_minutes: 20"))
        XCTAssertTrue(text.contains("session_start: \(ShakeReportTime.text(origin))"))
        XCTAssertTrue(text.contains("window_start: \(ShakeReportTime.text(origin.addingTimeInterval(5 * 60)))"))
        XCTAssertTrue(text.contains("kept-line"))
        XCTAssertTrue(text.contains("late-line"))
        XCTAssertFalse(text.contains("early-line"))
        let zone = TimeZone.current
        let keptStamp = ShakeReportTime.localClock(origin.addingTimeInterval(6 * 60), timeZone: zone)
        let lateStamp = ShakeReportTime.localClock(origin.addingTimeInterval(25 * 60), timeZone: zone)
        XCTAssertTrue(text.contains("\(keptStamp) kept-line"))
        XCTAssertTrue(text.contains("\(lateStamp) late-line"))
        XCTAssertTrue(text.contains("tz: \(ShakeReportTime.zoneOffset(origin.addingTimeInterval(25 * 60), timeZone: zone))"))
        XCTAssertTrue(text.contains("cut_by_20min: true"))
        XCTAssertTrue(text.contains("window_minutes: 20"))
        assertEventLinesAreStamped(text)
    }

    func testSignedInForegroundFiveMinutesKeepsFive() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let origin = clock.now
        let log = ShakeReportLog(clock: { clock.now })
        log.noteSignedInLaunchIfNeeded()
        log.record("at-foreground")
        clock.advance(5 * 60)
        log.record("at-five")

        let text = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertTrue(text.contains("entry: signed_in_foreground"))
        XCTAssertTrue(text.contains("cut_by_20min: false"))
        XCTAssertTrue(text.contains("window_minutes: 5"))
        XCTAssertTrue(text.contains("session_start: \(ShakeReportTime.text(origin))"))
        XCTAssertTrue(text.contains("at-foreground"))
        XCTAssertTrue(text.contains("at-five"))
    }

    func testShortBackgroundKeepsForegroundAndLongBackgroundMovesIt() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let origin = clock.now
        let log = ShakeReportLog(clock: { clock.now })
        log.noteSignedInLaunchIfNeeded()
        log.record("before-foreground")
        clock.advance(1)
        log.scene(.background)
        clock.advance(10)
        log.scene(.active)

        let kept = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertTrue(kept.contains("session_start: \(ShakeReportTime.text(origin))"))
        XCTAssertTrue(kept.contains("before-foreground"))

        clock.advance(1)
        log.scene(.background)
        clock.advance(45)
        log.scene(.active)
        let movedTo = clock.now
        log.record("after-return")
        let moved = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertTrue(moved.contains("session_start: \(ShakeReportTime.text(movedTo))"))
        XCTAssertTrue(moved.contains("after-return"))
        XCTAssertFalse(moved.contains("before-foreground"))
        XCTAssertTrue(log.storedLineTexts().contains("before-foreground"))
    }

    func testGetStartedSessionStartSurvivesALongBackground() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let origin = clock.now
        let log = ShakeReportLog(clock: { clock.now })
        log.beginGetStarted()
        clock.advance(1)
        log.scene(.background)
        clock.advance(45)
        log.scene(.active)
        let text = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertTrue(text.contains("entry: get_started"))
        XCTAssertTrue(text.contains("session_start: \(ShakeReportTime.text(origin))"))
    }

    func testExternalPresentationDoesNotMoveForegroundAcrossSends() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let origin = clock.now
        let log = ShakeReportLog(clock: { clock.now })
        log.noteSignedInLaunchIfNeeded()
        let anchor = "session_start: \(ShakeReportTime.text(origin))"

        log.beginExternalPresentation()
        clock.advance(1)
        log.scene(.background)
        clock.advance(45)
        log.scene(.active)
        log.endExternalPresentation()
        let first = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertTrue(first.contains(anchor))

        log.beginExternalPresentation()
        clock.advance(1)
        log.scene(.background)
        clock.advance(45)
        log.scene(.active)
        log.endExternalPresentation()
        let second = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertTrue(second.contains(anchor))
    }

    func testSignOutDropsLinesAndDemoContinueDropsEarlierLines() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let log = ShakeReportLog(clock: { clock.now })
        log.beginGetStarted()
        log.record("gone-line")
        log.endSession()
        let signedOut = log.render(description: "draft", context: sampleContext(), identity: nil)
        XCTAssertFalse(signedOut.contains("gone-line"))
        XCTAssertTrue(signedOut.contains("session: none"))
        XCTAssertTrue(signedOut.contains("entry: none"))
        XCTAssertTrue(signedOut.contains("draft"))

        log.beginGetStarted()
        log.record("old-line")
        log.beginDemoContinue()
        log.record("new-line")
        let demo = log.render(description: "", context: sampleContext(), identity: nil)
        XCTAssertFalse(demo.contains("old-line"))
        XCTAssertFalse(demo.contains("gone-line"))
        XCTAssertTrue(demo.contains("new-line"))
        XCTAssertTrue(demo.contains("entry: demo_continue"))
    }

    func testSecondRenderRecomputesTheSameSession() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let log = ShakeReportLog(clock: { clock.now })
        log.beginGetStarted()
        log.record("first-line")
        let first = log.render(description: "note", context: sampleContext(), identity: nil)
        let second = log.render(description: "note", context: sampleContext(), identity: nil)
        XCTAssertEqual(first, second)

        log.record("second-line")
        let third = log.render(description: "note", context: sampleContext(), identity: nil)
        XCTAssertTrue(third.contains("first-line"))
        XCTAssertTrue(third.contains("second-line"))
        XCTAssertFalse(first.contains("second-line"))
        XCTAssertEqual(sessionStartLine(first), sessionStartLine(third))
    }

    func testNoSessionWritesSessionNone() {
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let log = ShakeReportLog(clock: { clock.now })
        log.record("hidden-line")
        let text = log.render(description: "hello", context: sampleContext(), identity: nil)
        XCTAssertTrue(text.contains("session: none"))
        XCTAssertTrue(text.contains("session_start: none"))
        XCTAssertTrue(text.contains("window_start: none"))
        XCTAssertTrue(text.contains("entry: none"))
        XCTAssertTrue(text.contains("hello"))
        XCTAssertFalse(text.contains("hidden-line"))
    }

    func testFieldExclusionLogsIdOnly() {
        let secrets = [
            ("password", "p@ss w0rd"),
            ("passwordConfirm", "other-secret"),
            ("email", "qa@example.com"),
            ("otp", "1234"),
            ("name", "Iveta"),
            ("card", "MINIT-CONTRACT1"),
        ]
        for (id, secret) in secrets {
            var state = DiagnosticFieldState()
            let focused = state.focusChanged(id: id, isFocused: true)
            let typed = state.textChanged(id: id, isFocused: true)
            let again = state.textChanged(id: id, isFocused: true)
            XCTAssertEqual(focused, "field focused \(id)")
            XCTAssertEqual(typed, "field typed \(id)")
            XCTAssertNil(again)
            let blob = [focused, typed].compactMap { $0 }.joined(separator: "\n")
            XCTAssertFalse(blob.contains(secret))

            _ = state.focusChanged(id: id, isFocused: false)
            XCTAssertEqual(state.textChanged(id: id, isFocused: true), "field typed \(id)")
        }
    }

    func testRouteOmitsUserId() {
        let names = [
            ShakeReportRoute.screen(.authenticated(userId: "secret-user")),
            ShakeReportRoute.screen(.onboarding(userId: "secret-user")),
            ShakeReportRoute.screen(.onboardingStatusFailed(userId: "secret-user")),
        ]
        XCTAssertEqual(names, ["authenticated", "onboarding", "onboardingStatusFailed"])
        XCTAssertFalse(names.joined(separator: " ").contains("secret-user"))
    }

    func testCatalogHasSheetCopyInEnglishSlovakAndHungarian() {
        let expected: [String: [String: String]] = [
            "shake.report.title": [
                "en": "Report a problem",
                "sk": "Nahláste problém",
                "hu": "Jelents egy problémát",
            ],
            "shake.report.placeholder": [
                "en": "What happened? (optional)",
                "sk": "Opíšte, čo sa stalo (nemusíte)",
                "hu": "Írd le, mi történt (nem kötelező)",
            ],
            "shake.report.send": [
                "en": "Send",
                "sk": "Odoslať",
                "hu": "Küldés",
            ],
            "shake.report.prompt.title": [
                "en": "Shake detected",
                "sk": "Zistené zatrasenie",
                "hu": "Rázást észleltünk",
            ],
            "shake.report.prompt.message": [
                "en": "Would you like to report a bug or suggest an improvement?",
                "sk": "Chcete nahlásiť chybu alebo navrhnúť zlepšenie?",
                "hu": "Szeretnél hibát bejelenteni vagy fejlesztést javasolni?",
            ],
            "shake.report.prompt.report": [
                "en": "Report",
                "sk": "Nahlásiť",
                "hu": "Bejelentés",
            ],
        ]
        for (key, translations) in expected {
            for (language, value) in translations {
                XCTAssertEqual(
                    AppLocalizedString.string(key, locale: Locale(identifier: language)),
                    value,
                    "\(language) \(key)"
                )
            }
        }
    }

    func testLoadRecordsTwoLinesWhenUnauthorizedIsRetried() async throws {
        let log = ShakeReportLog.shared
        let wasEnabled = log.isEnabled
        log.setEnabled(true)
        defer {
            log.endSession()
            log.setEnabled(wasEnabled)
        }
        log.endSession()

        let context = URLProtocolStub.Context()
        let url = URL(string: "https://api.minit.test/v1/shake-probe")!
        context.enqueue(url: url, statusCode: 401, data: Data("first-body".utf8))
        context.enqueue(url: url, statusCode: 200, data: Data(#"{"id":1}"#.utf8))
        let client = NetworkClientImpl(
            baseURL: "https://api.minit.test",
            tokenProvider: RecordingTokenProvider(initial: "fake-token", refreshed: "fake-token-refreshed"),
            sessionConfiguration: context.makeConfiguration()
        )

        let user: ShakeHTTPProbe = try await client.request("/v1/shake-probe", method: .GET)
        XCTAssertEqual(user.id, 1)

        let stored = log.storedLineTexts()
        let unauthorized = try XCTUnwrap(stored.firstIndex { $0.hasPrefix("GET /v1/shake-probe ") && $0.contains(" 401 ") })
        let ok = try XCTUnwrap(stored.firstIndex { $0.hasPrefix("GET /v1/shake-probe ") && $0.contains(" 200 ") })
        assertHTTPLine(stored[unauthorized], method: "GET", path: "/v1/shake-probe", status: 401)
        assertHTTPLine(stored[ok], method: "GET", path: "/v1/shake-probe", status: 200)
        XCTAssertGreaterThan(ok, unauthorized)
        let firstBody = Data("first-body".utf8)
        XCTAssertEqual(stored[unauthorized + 1], "text/plain \(firstBody.count) bytes")
        XCTAssertEqual(stored[ok + 1], "{\"id\":1}")
        XCTAssertEqual(ok, unauthorized + 2)
        let blob = stored.joined(separator: "\n")
        XCTAssertFalse(blob.contains("fake-token"))
        XCTAssertFalse(blob.contains("first-body"))
    }

    func testResponseBodyScrubsNestedSecretsCardCodesAndKeepsUidAndEmail() throws {
        let payload = """
        {
          "uid": "uid-full-123",
          "email": "qa@example.com",
          "Token": "top-SECRET",
          "backgroundToken": "pink",
          "ok": true,
          "link": "https://api.minit.test/v1/loyalty-cards/MINIT-URLCODE",
          "user": {
            "accessToken": "access-SECRET",
            "access_token": "access-snake-SECRET",
            "refreshToken": "refresh-SECRET",
            "refresh_token": "refresh-snake-SECRET",
            "idToken": "id-SECRET",
            "id_token": "snake-SECRET",
            "ID_TOKEN": "upper-SECRET",
            "password": "pw-SECRET",
            "Authorization": "auth-SECRET",
            "cookie": "cookie-SECRET",
            "Set-Cookie": "set-SECRET",
            "profile": {
              "email": "nested@example.com",
              "loyaltyCardId": "MINIT-CONTRACT1",
              "loyalty_card_id": "MINIT-SNAKE",
              "CODE": "MINIT-NESTED",
              "points": 3210
            }
          },
          "cards": [
            {
              "barcode": "BAR-111",
              "CardNumber": "NUM-222",
              "EAN": "EAN-333",
              "card_code": "CARD-444",
              "name": "Iveta"
            },
            { "uid": "uid-array", "token": "array-SECRET" }
          ],
          "error": { "code": "not_found", "message": "Not found" }
        }
        """
        let line = ShakeReportBody.line(
            data: Data(payload.utf8),
            contentType: "application/json; charset=utf-8"
        )
        XCTAssertFalse(line.contains("\n"), line)
        XCTAssertFalse(line.contains(": "), line)

        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
        )
        XCTAssertEqual(root["uid"] as? String, "uid-full-123")
        XCTAssertEqual(root["email"] as? String, "qa@example.com")
        XCTAssertEqual(root["Token"] as? String, "***")
        XCTAssertEqual(root["backgroundToken"] as? String, "pink")
        XCTAssertEqual(root["ok"] as? Bool, true)
        XCTAssertEqual(root["link"] as? String, "https://api.minit.test/v1/loyalty-cards/[redacted]")

        let user = try XCTUnwrap(root["user"] as? [String: Any])
        for key in ["accessToken", "access_token", "refreshToken", "refresh_token", "idToken", "id_token", "ID_TOKEN", "password", "Authorization", "cookie", "Set-Cookie"] {
            XCTAssertEqual(user[key] as? String, "***", key)
        }
        let profile = try XCTUnwrap(user["profile"] as? [String: Any])
        XCTAssertEqual(profile["email"] as? String, "nested@example.com")
        XCTAssertEqual(profile["loyaltyCardId"] as? String, "***")
        XCTAssertEqual(profile["loyalty_card_id"] as? String, "***")
        XCTAssertEqual(profile["CODE"] as? String, "***")
        XCTAssertEqual(profile["points"] as? Int, 3210)

        let cards = try XCTUnwrap(root["cards"] as? [[String: Any]])
        XCTAssertEqual(cards[0]["barcode"] as? String, "***")
        XCTAssertEqual(cards[0]["CardNumber"] as? String, "***")
        XCTAssertEqual(cards[0]["EAN"] as? String, "***")
        XCTAssertEqual(cards[0]["card_code"] as? String, "***")
        XCTAssertEqual(cards[0]["name"] as? String, "Iveta")
        XCTAssertEqual(cards[1]["uid"] as? String, "uid-array")
        XCTAssertEqual(cards[1]["token"] as? String, "***")

        let error = try XCTUnwrap(root["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? String, "not_found")
        XCTAssertEqual(error["message"] as? String, "Not found")

        let secrets = [
            "top-SECRET", "access-SECRET", "access-snake-SECRET", "refresh-SECRET",
            "refresh-snake-SECRET", "id-SECRET", "snake-SECRET", "upper-SECRET",
            "pw-SECRET", "auth-SECRET", "cookie-SECRET", "set-SECRET", "array-SECRET",
            "MINIT-CONTRACT1", "MINIT-SNAKE", "MINIT-NESTED", "MINIT-URLCODE",
            "BAR-111", "NUM-222", "EAN-333", "CARD-444",
        ]
        for secret in secrets {
            XCTAssertFalse(line.contains(secret), secret)
        }

        let arrayLine = ShakeReportBody.line(
            data: Data(#"[{"code":"MINIT-ARRAY","email":"array@example.com"}]"#.utf8),
            contentType: "application/problem+json"
        )
        let array = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(arrayLine.utf8)) as? [[String: Any]]
        )
        XCTAssertEqual(array[0]["code"] as? String, "***")
        XCTAssertEqual(array[0]["email"] as? String, "array@example.com")
        XCTAssertFalse(arrayLine.contains("MINIT-ARRAY"))
    }

    func testResponseBodyTruncatesAt2048Bytes() {
        let overhead = Data(#"{"note":""}"#.utf8).count
        let extra = 50
        let note = String(repeating: "a", count: ShakeReportBody.maxBytes - overhead + extra)
        let raw = #"{"note":"\#(note)"}"#
        XCTAssertEqual(Data(raw.utf8).count, ShakeReportBody.maxBytes + extra)
        let line = ShakeReportBody.line(data: Data(raw.utf8), contentType: "application/json")
        let marker = "…(truncated \(extra) bytes)"
        XCTAssertTrue(line.hasSuffix(marker), line)
        let prefix = String(line.dropLast(marker.count))
        XCTAssertEqual(Data(prefix.utf8).count, ShakeReportBody.maxBytes)
        XCTAssertEqual(
            prefix,
            String(decoding: Data(raw.utf8).prefix(ShakeReportBody.maxBytes), as: UTF8.self)
        )
        XCTAssertFalse(line.contains("\n"))

        let exactNote = String(repeating: "b", count: ShakeReportBody.maxBytes - overhead)
        let exact = #"{"note":"\#(exactNote)"}"#
        XCTAssertEqual(Data(exact.utf8).count, ShakeReportBody.maxBytes)
        XCTAssertEqual(
            ShakeReportBody.line(data: Data(exact.utf8), contentType: "application/json"),
            exact
        )

        let plain = Data(("  " + String(repeating: "c", count: ShakeReportBody.maxBytes + 7) + "\n").utf8)
        let plainLine = ShakeReportBody.line(data: plain, contentType: "text/plain")
        XCTAssertEqual(plainLine, "text/plain \(plain.count) bytes")
        XCTAssertFalse(plainLine.contains("ccc"))

        let lead = "{\"note\":\""
        let headCount = ShakeReportBody.maxBytes - 1 - Data(lead.utf8).count
        let head = String(repeating: "d", count: headCount)
        let tail = String(repeating: "e", count: 10)
        let split = lead + head + "€" + tail + "\"}"
        let splitBytes = Data(split.utf8)
        XCTAssertEqual(splitBytes[ShakeReportBody.maxBytes] & 0b1100_0000, 0b1000_0000)
        let splitLine = ShakeReportBody.line(data: splitBytes, contentType: "application/json")
        let cut = splitBytes.count - (ShakeReportBody.maxBytes - 1)
        let splitMarker = "…(truncated \(cut) bytes)"
        XCTAssertTrue(splitLine.hasSuffix(splitMarker), splitLine)
        XCTAssertEqual(String(splitLine.dropLast(splitMarker.count)), lead + head)
        XCTAssertFalse(splitLine.contains("€"))

        let secret = String(repeating: "S", count: 3000)
        let oversized = #"{"email":"qa@example.com","token":"\#(secret)"}"#
        XCTAssertGreaterThan(Data(oversized.utf8).count, ShakeReportBody.maxBytes)
        let scrubbed = ShakeReportBody.line(data: Data(oversized.utf8), contentType: "application/json")
        XCTAssertFalse(scrubbed.contains("S"), scrubbed)
        XCTAssertTrue(scrubbed.contains("\"token\":\"***\""), scrubbed)
        XCTAssertTrue(scrubbed.contains("qa@example.com"), scrubbed)
        XCTAssertFalse(scrubbed.contains("truncated"), scrubbed)
    }

    func testBinaryResponseBodySkipsTheBytes() {
        let secret = Data("MINIT-CONTRACT1".utf8)
        XCTAssertEqual(
            ShakeReportBody.line(data: secret, contentType: "image/webp"),
            "image/webp \(secret.count) bytes"
        )
        XCTAssertEqual(
            ShakeReportBody.line(data: secret, contentType: "Image/PNG; charset=binary"),
            "image/png \(secret.count) bytes"
        )
        XCTAssertEqual(
            ShakeReportBody.line(data: secret, contentType: "application/octet-stream"),
            "application/octet-stream \(secret.count) bytes"
        )
        XCTAssertEqual(
            ShakeReportBody.line(data: secret, contentType: "application/pdf"),
            "application/pdf \(secret.count) bytes"
        )
        let jsonBytes = Data(#"{"token":"json-SECRET","email":"qa@example.com"}"#.utf8)
        let skipped = ShakeReportBody.line(data: jsonBytes, contentType: "application/octet-stream")
        XCTAssertEqual(skipped, "application/octet-stream \(jsonBytes.count) bytes")
        XCTAssertFalse(skipped.contains("json-SECRET"))
        XCTAssertFalse(skipped.contains("MINIT-CONTRACT1"))
        let html = Data("<html>Bearer secret-token</html>".utf8)
        XCTAssertEqual(
            ShakeReportBody.line(data: html, contentType: "text/html; charset=utf-8"),
            "text/html \(html.count) bytes"
        )
        XCTAssertFalse(ShakeReportBody.line(data: html, contentType: "text/html").contains("secret-token"))
        let nope = Data("{\"token\":\"nope-SECRET\"".utf8)
        let invalid = ShakeReportBody.line(data: nope, contentType: "application/json")
        XCTAssertEqual(invalid, "application/json \(nope.count) bytes")
        XCTAssertFalse(invalid.contains("nope-SECRET"))
    }

    func testResponseBodyScrubsVariantsScalarsAndEmbeddedSecrets() throws {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.signaturevalue"
        let payload: [String: Any] = [
            "cookies": "cookies-SECRET",
            "authToken": "auth-SECRET",
            "sessionToken": "session-SECRET",
            "customToken": "custom-SECRET",
            "fcmToken": "fcm-SECRET",
            "pushToken": "push-SECRET",
            "x-access-token": "xaccess-SECRET",
            "newPassword": "newpw-SECRET",
            "currentPassword": "curpw-SECRET",
            "passwords": "pwds-SECRET",
            "clientSecret": "client-SECRET",
            "secret": "plain-SECRET",
            "apiKey": "api-SECRET",
            "loyaltyCardCode": "LOYAL-SECRET",
            "cardBarcode": "CARDBAR-SECRET",
            "qrCode": "QR-SECRET",
            "verificationCode": "VER-SECRET",
            "otp": "OTP-SECRET",
            "countryCode": "SK",
            "status": "registered",
            "reasonCode": "welcome",
            "message": "see \(jwt) Bearer bearer-SECRET",
            "url": "https://cdn.example/a.png?X-Goog-Signature=GOOG-SECRET&access_token=ACCESS-SECRET&ok=1",
            "payload": #"{"token":"payload-SECRET","email":"payload@example.com"}"#,
            "items": [[["password": "deep-SECRET", "email": "deep@example.com", "code": "not_found"]]],
            "error": ["code": "already_registered", "message": "taken"],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let line = ShakeReportBody.line(data: data, contentType: "application/json")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        for key in [
            "cookies", "authToken", "sessionToken", "customToken", "fcmToken", "pushToken",
            "x-access-token", "newPassword", "currentPassword", "passwords", "clientSecret",
            "secret", "apiKey", "loyaltyCardCode", "cardBarcode", "qrCode", "verificationCode", "otp",
        ] {
            XCTAssertEqual(root[key] as? String, "***", key)
        }
        XCTAssertEqual(root["countryCode"] as? String, "SK")
        XCTAssertEqual(root["status"] as? String, "registered")
        XCTAssertEqual(root["reasonCode"] as? String, "welcome")
        XCTAssertEqual(root["message"] as? String, "see [redacted] Bearer [redacted]")
        XCTAssertEqual(root["url"] as? String, "https://cdn.example/a.png?ok=1")
        let embedded = try XCTUnwrap(root["payload"] as? String)
        let embeddedObject = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(embedded.utf8)) as? [String: Any])
        XCTAssertEqual(embeddedObject["token"] as? String, "***")
        XCTAssertEqual(embeddedObject["email"] as? String, "payload@example.com")
        let items = try XCTUnwrap(root["items"] as? [Any])
        let outer = try XCTUnwrap(items.first as? [Any])
        let deep = try XCTUnwrap(outer.first as? [String: Any])
        XCTAssertEqual(deep["password"] as? String, "***")
        XCTAssertEqual(deep["email"] as? String, "deep@example.com")
        XCTAssertEqual(deep["code"] as? String, "not_found")
        let error = try XCTUnwrap(root["error"] as? [String: Any])
        XCTAssertEqual(error["code"] as? String, "already_registered")

        let secrets = [
            "cookies-SECRET", "auth-SECRET", "session-SECRET", "custom-SECRET", "fcm-SECRET",
            "push-SECRET", "xaccess-SECRET", "newpw-SECRET", "curpw-SECRET", "pwds-SECRET",
            "client-SECRET", "plain-SECRET", "api-SECRET", "LOYAL-SECRET", "CARDBAR-SECRET",
            "QR-SECRET", "VER-SECRET", "OTP-SECRET", "payload-SECRET", "deep-SECRET",
            "bearer-SECRET", "GOOG-SECRET", "ACCESS-SECRET", jwt,
        ]
        for secret in secrets {
            XCTAssertFalse(line.contains(secret), secret)
        }

        XCTAssertEqual(
            ShakeReportBody.line(data: Data(#"{"z":1,"a":2}"#.utf8), contentType: "application/json"),
            #"{"a":2,"z":1}"#
        )
        XCTAssertEqual(ShakeReportBody.line(data: Data("42".utf8), contentType: "application/json"), "42")
        XCTAssertEqual(ShakeReportBody.line(data: Data("true".utf8), contentType: "application/json"), "true")
        XCTAssertEqual(ShakeReportBody.line(data: Data("false".utf8), contentType: "application/json"), "false")
        XCTAssertEqual(ShakeReportBody.line(data: Data("null".utf8), contentType: "application/json"), "null")
        XCTAssertEqual(
            ShakeReportBody.line(data: Data("\"hello\"".utf8), contentType: "application/json"),
            "\"hello\""
        )
        let wrapped = Data("  \"\(jwt)\"  ".utf8)
        let scalar = ShakeReportBody.line(data: wrapped, contentType: "application/json")
        XCTAssertEqual(scalar, "\"[redacted]\"")
        XCTAssertFalse(scalar.contains(jwt))
        XCTAssertEqual(
            ShakeReportBody.line(data: Data("\"Bearer opaque-token\"".utf8), contentType: "application/json"),
            "\"Bearer [redacted]\""
        )

        let plainJSON = Data(#"{"token":"plain-SECRET","email":"qa@example.com"}"#.utf8)
        let plainLine = ShakeReportBody.line(data: plainJSON, contentType: "text/plain")
        XCTAssertTrue(plainLine.contains("\"token\":\"***\""), plainLine)
        XCTAssertTrue(plainLine.contains("qa@example.com"), plainLine)
        XCTAssertFalse(plainLine.contains("plain-SECRET"))

        XCTAssertEqual(ShakeReportBody.line(data: Data(), contentType: "application/json"), "empty")
        XCTAssertEqual(ShakeReportBody.line(data: Data(), contentType: nil), "empty")
        let unspecified = Data("hello-secret".utf8)
        XCTAssertEqual(
            ShakeReportBody.line(data: unspecified, contentType: nil),
            "text/plain \(unspecified.count) bytes"
        )
        XCTAssertFalse(ShakeReportBody.line(data: unspecified, contentType: nil).contains("hello-secret"))
        XCTAssertEqual(
            ShakeReportBody.line(data: Data([0xFF, 0xFE, 0xFD]), contentType: nil),
            "application/octet-stream 3 bytes"
        )

        var huge = Data("{\"token\":\"SECRET-LEAK\"}".utf8)
        huge.append(Data(repeating: 0x61, count: ShakeReportBody.maxCaptureBytes))
        let capped = ShakeReportBody.line(data: huge, contentType: "application/json")
        XCTAssertEqual(capped, "application/json \(huge.count) bytes (not captured)")
        XCTAssertFalse(capped.contains("SECRET-LEAK"))
        let boundary = Data(repeating: 0x61, count: ShakeReportBody.maxCaptureBytes)
        let boundaryLine = ShakeReportBody.line(data: boundary, contentType: "application/json")
        XCTAssertEqual(boundaryLine, "application/json \(boundary.count) bytes")
        XCTAssertFalse(boundaryLine.contains("not captured"))

        let bomb = String(repeating: "[", count: 80) + #"{"token":"bomb-SECRET"}"# + String(repeating: "]", count: 80)
        let bombData = Data(bomb.utf8)
        let bombLine = ShakeReportBody.line(data: bombData, contentType: "application/json")
        XCTAssertEqual(bombLine, "application/json \(bombData.count) bytes")
        XCTAssertFalse(bombLine.contains("bomb-SECRET"))
    }

    func testRequestLineDropsSignedAndTokenQueryNames() {
        let log = ShakeReportLog()
        let url = URL(string: "https://cdn.example/a.webp?access_token=ACCESS-SECRET&id_token=ID-SECRET&refresh_token=REFRESH-SECRET&code=AUTH-SECRET&key=API-SECRET&sig=SIG-SECRET&X-Amz-Signature=AMZ-SECRET&X-Goog-Signature=GOOG-SECRET&access%5Ftoken=ENCODED-SECRET&sign=keepme&keys=keepkeys&ok=1")!
        log.recordHTTP(
            method: "GET",
            url: url,
            status: 200,
            milliseconds: 3,
            body: Data("BYTES".utf8),
            contentType: "image/webp"
        )
        log.recordHTTP(
            method: "GET",
            url: URL(string: "https://api.minit.test/v1/empty")!,
            status: 204,
            milliseconds: 1,
            body: Data(),
            contentType: "application/json"
        )
        let stored = log.storedLineTexts()
        XCTAssertEqual(stored.count, 4, stored.joined(separator: "\n"))
        XCTAssertTrue(stored[0].contains("ok=1"), stored[0])
        XCTAssertTrue(stored[0].contains("sign=keepme"), stored[0])
        XCTAssertTrue(stored[0].contains("keys=keepkeys"), stored[0])
        XCTAssertEqual(stored[1], "image/webp 5 bytes")
        XCTAssertEqual(stored[3], "empty")
        for secret in ["ACCESS-SECRET", "ID-SECRET", "REFRESH-SECRET", "AUTH-SECRET", "API-SECRET", "SIG-SECRET", "AMZ-SECRET", "GOOG-SECRET", "ENCODED-SECRET", "BYTES"] {
            XCTAssertFalse(stored[0].contains(secret), secret)
            XCTAssertFalse(stored[1].contains(secret), secret)
        }
    }

    func testConcurrentHTTPPairsStayAdjacent() {
        let log = ShakeReportLog()
        let group = DispatchGroup()
        let count = 40
        for index in 0..<count {
            group.enter()
            DispatchQueue.global().async {
                let body = Data("{\"n\":\(index),\"token\":\"secret-\(index)\"}".utf8)
                log.recordHTTP(
                    method: "GET",
                    url: URL(string: "https://api.minit.test/v1/pair/\(index)?token=abc")!,
                    status: 200,
                    milliseconds: index,
                    body: body,
                    contentType: "application/json"
                )
                group.leave()
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 10), .success)
        let lines = log.storedLineTexts()
        XCTAssertEqual(lines.count, count * 2, lines.joined(separator: "\n"))
        var seen = Set<Int>()
        var index = 0
        while index < lines.count {
            let request = lines[index]
            let body = lines[index + 1]
            XCTAssertTrue(request.hasPrefix("GET /v1/pair/"), request)
            XCTAssertFalse(request.contains("token="), request)
            let path = request.split(separator: " ")[1]
            let id = Int(path.split(separator: "/").last ?? "")
            XCTAssertNotNil(id, request)
            if let id {
                XCTAssertTrue(body.contains("\"n\":\(id)"), body)
                XCTAssertTrue(body.contains("\"token\":\"***\""), body)
                XCTAssertFalse(body.contains("secret-"), body)
                seen.insert(id)
            }
            index += 2
        }
        XCTAssertEqual(seen, Set(0..<count))
    }

    func testResponseBodyFollowsTheRequestLineWithoutTheGenericScrubber() {
        let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.signaturevalue"
        let zone = TimeZone(secondsFromGMT: 0)!
        let clock = TestClock(Date(timeIntervalSince1970: 1_700_000_000))
        let log = ShakeReportLog(clock: { clock.now }, timeZone: { zone })
        log.beginGetStarted()
        log.record("note Authorization: Bearer \(jwt) after")
        let url = URL(string: "https://api.minit.test/v1/loyalty-cards/MINIT-CONTRACT1/claim?token=abc&ok=1")
        let body = Data(
            #"{"uid":"uid-full-123","email":"qa@example.com","code":"MINIT-CONTRACT1","link":"/v1/loyalty-cards/MINIT-CONTRACT1"}"#.utf8
        )
        log.recordHTTP(
            method: "GET",
            url: url,
            status: 200,
            milliseconds: 54,
            body: body,
            contentType: "application/json"
        )

        let stored = log.storedLineTexts()
        XCTAssertEqual(stored.count, 3, stored.joined(separator: "\n"))
        XCTAssertFalse(stored[0].contains(jwt))
        XCTAssertTrue(stored[0].contains("note"))
        XCTAssertTrue(stored[0].contains("after"))
        XCTAssertEqual(stored[1], "GET /v1/loyalty-cards/[redacted]/claim?ok=1 200 54ms")
        XCTAssertFalse(stored[1].contains("MINIT-CONTRACT1"))
        XCTAssertFalse(stored[1].contains("token="))
        XCTAssertTrue(stored[2].contains("\"email\":\"qa@example.com\""))
        XCTAssertTrue(stored[2].contains("\"uid\":\"uid-full-123\""))
        XCTAssertTrue(stored[2].contains("\"code\":\"***\""))
        XCTAssertTrue(stored[2].contains("/v1/loyalty-cards/[redacted]"))
        XCTAssertFalse(stored[2].contains("MINIT-CONTRACT1"))
        XCTAssertFalse(stored[2].contains(jwt))

        let stamp = ShakeReportTime.localClock(clock.now, timeZone: zone)
        let text = log.render(description: "note", context: sampleContext(), identity: nil)
        let events = reportEventLines(in: text)
        XCTAssertEqual(events.count, 3, text)
        XCTAssertTrue(events[1].hasPrefix("\(stamp) GET /v1/loyalty-cards/[redacted]/claim?ok=1 200 54ms"))
        XCTAssertTrue(events[2].hasPrefix("\(stamp) {"))
        XCTAssertEqual(String(events[1].prefix(12)), String(events[2].prefix(12)))
        assertEventLinesAreStamped(text)

        let off = ShakeReportLog(enabled: false)
        off.recordHTTP(
            method: "GET",
            url: url,
            status: 200,
            milliseconds: 1,
            body: body,
            contentType: "application/json"
        )
        XCTAssertTrue(off.storedLineTexts().isEmpty)

        clock.advance(21 * 60)
        log.record("later-line")
        XCTAssertEqual(log.storedLineTexts(), ["later-line"])
    }

    func testClientLogsTheResponseBodyOnTheNextLine() async throws {
        let log = ShakeReportLog.shared
        let wasEnabled = log.isEnabled
        log.setEnabled(true)
        defer {
            log.endSession()
            log.setEnabled(wasEnabled)
        }
        log.endSession()
        log.beginGetStarted()

        let context = URLProtocolStub.Context()
        let url = URL(string: "https://api.minit.test/v1/me")!
        context.enqueue(
            url: url,
            statusCode: 401,
            data: Data("  first-body\n".utf8),
            headers: ["Content-Type": "text/plain"]
        )
        let json = """
        {
          "uid": "uid-full-123",
          "email": "qa@example.com",
          "idToken": "id-SECRET",
          "code": "MINIT-CONTRACT1"
        }
        """
        context.enqueue(
            url: url,
            statusCode: 200,
            data: Data(json.utf8),
            headers: ["Content-Type": "application/json; charset=utf-8"]
        )
        let client = NetworkClientImpl(
            baseURL: "https://api.minit.test",
            tokenProvider: RecordingTokenProvider(initial: "fake-token", refreshed: "fake-token-refreshed"),
            sessionConfiguration: context.makeConfiguration()
        )
        let user: ShakeBodyProbe = try await client.request("/v1/me", method: .GET)
        XCTAssertEqual(user.uid, "uid-full-123")
        XCTAssertEqual(user.email, "qa@example.com")

        let imageURL = URL(string: "https://api.minit.test/v1/media/avatars/a.webp")!
        let image = Data("MINIT-CONTRACT1-BYTES".utf8)
        context.stub(
            url: imageURL,
            statusCode: 200,
            data: image,
            headers: ["Content-Type": "image/webp"]
        )
        let loaded = try await client.data(imageURL)
        XCTAssertEqual(loaded, image)

        let stored = log.storedLineTexts()
        let unauthorized = try XCTUnwrap(stored.firstIndex { $0.hasPrefix("GET /v1/me ") && $0.contains(" 401 ") })
        assertHTTPLine(stored[unauthorized], method: "GET", path: "/v1/me", status: 401)
        let plain = Data("  first-body\n".utf8)
        XCTAssertEqual(stored[unauthorized + 1], "text/plain \(plain.count) bytes")
        XCTAssertFalse(stored[unauthorized + 1].contains("first-body"))
        let ok = try XCTUnwrap(stored.firstIndex { $0.hasPrefix("GET /v1/me ") && $0.contains(" 200 ") })
        XCTAssertGreaterThan(ok, unauthorized)
        assertHTTPLine(stored[ok], method: "GET", path: "/v1/me", status: 200)
        let body = stored[ok + 1]
        XCTAssertTrue(body.contains("\"email\":\"qa@example.com\""), body)
        XCTAssertTrue(body.contains("\"uid\":\"uid-full-123\""), body)
        XCTAssertTrue(body.contains("\"idToken\":\"***\""), body)
        XCTAssertTrue(body.contains("\"code\":\"***\""), body)
        XCTAssertFalse(body.contains("id-SECRET"), body)
        XCTAssertFalse(body.contains("MINIT-CONTRACT1"), body)
        XCTAssertFalse(body.contains("\n"), body)
        let imageLine = try XCTUnwrap(stored.firstIndex { $0.hasPrefix("GET /v1/media/avatars/a.webp ") })
        assertHTTPLine(stored[imageLine], method: "GET", path: "/v1/media/avatars/a.webp", status: 200)
        XCTAssertEqual(stored[imageLine + 1], "image/webp \(image.count) bytes")
        XCTAssertFalse(stored[imageLine + 1].contains("MINIT-CONTRACT1"))

        let ours = [stored[unauthorized], stored[unauthorized + 1], stored[ok], body, stored[imageLine], stored[imageLine + 1]]
        let blob = ours.joined(separator: "\n")
        XCTAssertFalse(blob.contains("fake-token"))
        XCTAssertFalse(blob.contains("fake-token-refreshed"))
        XCTAssertFalse(blob.contains("id-SECRET"))

        let text = log.render(
            description: "note",
            context: sampleContext(),
            identity: ShakeReportIdentity(uid: "uid-full-123", email: "qa@example.com")
        )
        XCTAssertTrue(text.contains("uid: uid-full-123"))
        XCTAssertTrue(text.contains("email: qa@example.com"))
        let events = reportEventLines(in: text)
        let unauthorizedEvent = try XCTUnwrap(events.firstIndex { $0.contains("GET /v1/me ") && $0.contains(" 401 ") })
        XCTAssertEqual(String(events[unauthorizedEvent].prefix(12)), String(events[unauthorizedEvent + 1].prefix(12)))
        XCTAssertEqual(String(events[unauthorizedEvent + 1].dropFirst(13)), "text/plain \(plain.count) bytes")
        let okEvent = try XCTUnwrap(events.firstIndex { $0.contains("GET /v1/me ") && $0.contains(" 200 ") })
        XCTAssertEqual(String(events[okEvent].prefix(12)), String(events[okEvent + 1].prefix(12)))
        XCTAssertTrue(events[okEvent + 1].dropFirst(13).hasPrefix("{"))
        let imageEvent = try XCTUnwrap(events.firstIndex { $0.contains("GET /v1/media/avatars/a.webp ") })
        XCTAssertEqual(String(events[imageEvent].prefix(12)), String(events[imageEvent + 1].prefix(12)))
        XCTAssertEqual(String(events[imageEvent + 1].dropFirst(13)), "image/webp \(image.count) bytes")
        assertEventLinesAreStamped(text)
    }

    func testReportAddressReadsPlistKey() async throws {
        let missing = try InfoPlistBundle([:])
        let empty = try InfoPlistBundle(["MinitShakeReportEmail": ""])
        let blank = try InfoPlistBundle(["MinitShakeReportEmail": "   "])
        let token = try InfoPlistBundle(["MinitShakeReportEmail": "$(MINIT_SHAKE_REPORT_EMAIL)"])
        let number = try InfoPlistBundle(["MinitShakeReportEmail": 1])
        let address = try InfoPlistBundle(["MinitShakeReportEmail": " qa@example.com "])
        defer {
            missing.remove()
            empty.remove()
            blank.remove()
            token.remove()
            number.remove()
            address.remove()
        }

        let missingAddress = await AppDependencies.reportAddress(bundle: missing.bundle)
        let emptyAddress = await AppDependencies.reportAddress(bundle: empty.bundle)
        let blankAddress = await AppDependencies.reportAddress(bundle: blank.bundle)
        let tokenAddress = await AppDependencies.reportAddress(bundle: token.bundle)
        let numberAddress = await AppDependencies.reportAddress(bundle: number.bundle)
        let setAddress = await AppDependencies.reportAddress(bundle: address.bundle)
        XCTAssertNil(missingAddress)
        XCTAssertNil(emptyAddress)
        XCTAssertNil(blankAddress)
        XCTAssertNil(tokenAddress)
        XCTAssertNil(numberAddress)
        XCTAssertEqual(setAddress, "qa@example.com")
    }

    func testForwardReachesTheLoggerSink() {
        let box = LineBox()
        let previous = AppLogger.lineSink
        defer { AppLogger.lineSink = previous }
        AppLogger.lineSink = { box.lines.append($0) }
        AppLogger.forward("Analytics: login_failed — invalidCredentials")
        XCTAssertEqual(box.lines, ["Analytics: login_failed — invalidCredentials"])
        AppLogger.lineSink = nil
        AppLogger.forward("ignored")
        XCTAssertEqual(box.lines, ["Analytics: login_failed — invalidCredentials"])
    }

    @MainActor
    func testSwiftUIControlsAndTabBarLogNamedTaps() throws {
        let log = ShakeReportLog.shared
        log.setEnabled(true)
        log.endSession()
        log.beginGetStarted()
        DiagnosticLines.record = { log.record($0) }
        ShakeReportHooks.install()
        ShakeReportTouches.resetForTests()

        let host = UIHostingController(rootView: ReportControlFixture())
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        defer { window.isHidden = true }

        func anchor(_ id: String, file: StaticString = #filePath, line: UInt = #line) throws -> UIView {
            let deadline = Date().addingTimeInterval(2)
            while Date() < deadline {
                host.view.layoutIfNeeded()
                if let view = DiagnosticTapAnchorView.installedView(id: id, in: window) {
                    return view
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            XCTFail("missing anchor \(id)", file: file, line: line)
            throw ReportTouchError.missing("anchor \(id)")
        }

        func tap(_ id: String) throws {
            let view = try anchor(id)
            let point = view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: window)
            try ReportTouchSynth.tap(at: point, in: window)
        }

        _ = try anchor("probe.button")
        log.endSession()
        log.beginGetStarted()

        try tap("probe.button")
        try tap("probe.toggle")
        try tap("probe.link")
        try tap("probe.row")
        try tap("probe.card")

        let lines = log.storedLineTexts()
        let blob = lines.joined(separator: "\n")
        for id in ["probe.button", "probe.toggle", "probe.link", "probe.row", "probe.card"] {
            XCTAssertEqual(lines.filter { $0 == "tap \(id)" }.count, 1, blob)
        }
        XCTAssertFalse(blob.contains("Iveta"), blob)

        let card = try anchor("probe.card")
        let start = card.convert(CGPoint(x: 24, y: card.bounds.midY), to: window)
        let end = CGPoint(x: start.x + 36, y: start.y)
        let beforeDrag = log.storedLineTexts().count
        try ReportTouchSynth.drag(from: start, to: end, in: window)
        XCTAssertEqual(
            log.storedLineTexts().count,
            beforeDrag,
            "a drag that ends inside the card is not a tap\n\(log.storedLineTexts().joined(separator: "\n"))"
        )

        let buttons = try waitForTabButtons(in: window)
        XCTAssertGreaterThanOrEqual(buttons.count, 2, "iOS 27 TabView should expose tab buttons")
        let offers = buttons[1]
        let offersPoint = offers.convert(CGPoint(x: offers.bounds.midX, y: offers.bounds.midY), to: window)
        try ReportTouchSynth.tap(at: offersPoint, in: window)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        var recorded = log.storedLineTexts()
        XCTAssertEqual(recorded.filter { $0 == "tap tab.offers" }.count, 1, recorded.joined(separator: "\n"))
        XCTAssertFalse(recorded.contains("route tab offers"), recorded.joined(separator: "\n"))

        try ReportTouchSynth.tap(at: offersPoint, in: window)
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        recorded = log.storedLineTexts()
        XCTAssertEqual(recorded.filter { $0 == "tap tab.offers" }.count, 2, recorded.joined(separator: "\n"))
        XCTAssertFalse(recorded.contains("route tab offers"), recorded.joined(separator: "\n"))
        XCTAssertFalse(recorded.joined(separator: "\n").contains("Offers"))
    }

    /// Close dismisses the popup inside the touch, which pulls the anchor out of the window
    /// before the hook records the tap. The id captured at touch-up still has to be logged.
    @MainActor
    func testTapNameSurvivesAControlRemovedDuringTheTouch() throws {
        let log = ShakeReportLog.shared
        log.setEnabled(true)
        log.endSession()
        log.beginGetStarted()
        DiagnosticLines.record = { log.record($0) }
        ShakeReportHooks.install()
        ShakeReportTouches.resetForTests()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let root = UIViewController()
        window.rootViewController = root
        window.makeKeyAndVisible()
        root.view.frame = window.bounds
        defer { window.isHidden = true }

        let anchor = DiagnosticTapAnchorView(frame: CGRect(x: 20, y: 20, width: 80, height: 44))
        anchor.tapID = "close"
        root.view.addSubview(anchor)

        let control = RemovingControl(frame: anchor.frame)
        control.onEnded = { anchor.removeFromSuperview() }
        root.view.addSubview(control)
        window.layoutIfNeeded()

        let point = control.convert(CGPoint(x: control.bounds.midX, y: control.bounds.midY), to: window)
        XCTAssertEqual(DiagnosticTapAnchorView.bestID(at: point, in: window), "close")
        try ReportTouchSynth.tap(at: point, in: window)

        XCTAssertNil(anchor.window)
        let lines = log.storedLineTexts()
        XCTAssertEqual(lines.filter { $0 == "tap close" }, ["tap close"], lines.joined(separator: "\n"))
        XCTAssertFalse(lines.contains("tap control"), lines.joined(separator: "\n"))
    }

    @MainActor
    private func waitForTabButtons(in window: UIWindow) throws -> [UIView] {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            window.layoutIfNeeded()
            let buttons = tabButtons(in: window)
            if buttons.count >= 2 { return buttons }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTFail("tab buttons did not appear")
        return tabButtons(in: window)
    }

    /// One button per tab. iOS 27 stacks a selected copy on the platter copy, and the
    /// title wrapper's class name also contains `_UITabButton`.
    private func tabButtons(in root: UIView) -> [UIView] {
        var found: [UIView] = []
        func walk(_ view: UIView) {
            if ShakeReportTapCapture.isTabButtonClass(NSStringFromClass(type(of: view))) {
                found.append(view)
            }
            for subview in view.subviews {
                walk(subview)
            }
        }
        walk(root)
        var clusters: [(midX: CGFloat, button: UIView)] = []
        for button in found {
            let frame = button.convert(button.bounds, to: root)
            guard frame.width > 1, frame.height > 1 else { continue }
            if let index = clusters.firstIndex(where: { abs($0.midX - frame.midX) < 30 }) {
                let existing = clusters[index].button.convert(clusters[index].button.bounds, to: root)
                if frame.width * frame.height >= existing.width * existing.height {
                    clusters[index] = (frame.midX, button)
                }
            } else {
                clusters.append((frame.midX, button))
            }
        }
        return clusters.sorted { $0.midX < $1.midX }.map(\.button)
    }

    private func tapName(for view: UIView) -> String? {
        ShakeReportTapNaming.name(for: ShakeReportTapCapture.target(for: view))
    }

    private func backLines(in log: ShakeReportLog) -> Int {
        log.storedLineTexts().filter { $0 == "tap back" }.count
    }

    private func assertEventLinesAreStamped(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        let parts = text.components(separatedBy: "\n\n")
        XCTAssertGreaterThanOrEqual(parts.count, 3, text, file: file, line: line)
        let header = parts[0]
        XCTAssertTrue(header.contains("session_start: "), file: file, line: line)
        XCTAssertNil(
            header.range(of: #"(?m)^\d{2}:\d{2}:\d{2}\.\d{3} "#, options: .regularExpression),
            header,
            file: file,
            line: line
        )
        let body = parts.dropFirst(2).joined(separator: "\n\n")
        if body.isEmpty || body == "session: none" { return }
        for event in body.split(separator: "\n") where !event.isEmpty {
            XCTAssertNotNil(
                event.range(of: #"^\d{2}:\d{2}:\d{2}\.\d{3} "#, options: .regularExpression),
                String(event),
                file: file,
                line: line
            )
        }
    }

    private func reportEventLines(in text: String) -> [String] {
        let parts = text.components(separatedBy: "\n\n")
        guard parts.count >= 3 else { return [] }
        return parts.dropFirst(2)
            .joined(separator: "\n\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    private func assertHTTPLine(_ line: String, method: String, path: String, status: Int) {
        let parts = line.split(separator: " ")
        XCTAssertEqual(parts.count, 4, line)
        XCTAssertEqual(String(parts[0]), method)
        XCTAssertEqual(String(parts[1]), path)
        XCTAssertEqual(String(parts[2]), String(status))
        XCTAssertTrue(parts[3].hasSuffix("ms"), line)
        XCTAssertNotNil(Int(parts[3].dropLast(2)), line)
    }

    private func sampleContext() -> ShakeReportContext {
        ShakeReportContext(
            version: "1.0",
            build: "1",
            environment: "development",
            dataBackend: "http",
            deviceModel: "iPhone",
            osVersion: "iOS 26.2",
            languageCode: "en"
        )
    }

    private func sessionStartLine(_ text: String) -> String? {
        text.split(separator: "\n").first { $0.hasPrefix("session_start:") }.map(String.init)
    }
}

nonisolated private final class TestClock: @unchecked Sendable {
    var now: Date
    init(_ now: Date) { self.now = now }
    func advance(_ interval: TimeInterval) { now = now.addingTimeInterval(interval) }
}

nonisolated private final class LineBox: @unchecked Sendable {
    var lines: [String] = []
}

private final class ShakeReportCardCell: UICollectionViewCell {}

private struct ShakeHTTPProbe: Decodable {
    let id: Int
}

private struct ShakeBodyProbe: Decodable {
    let uid: String
    let email: String
}

private struct ReportControlFixture: View {
    @State private var on = false
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 12) {
                    Button("Iveta") {}
                        .diagnosticTap("probe.button")
                        .frame(maxWidth: .infinity, minHeight: 44)
                    Toggle("Marketing", isOn: $on)
                        .diagnosticTap("probe.toggle")
                    NavigationLink("Open detail") { Text("Detail") }
                        .diagnosticTap("probe.link")
                    List {
                        Button("Row Iveta") {}
                            .diagnosticTap("probe.row")
                    }
                    .frame(height: 140)
                    Text("Iveta")
                        .frame(maxWidth: .infinity, minHeight: 80)
                        .background(Color.orange)
                        .diagnosticTap("probe.card")
                }
                .padding(.top, 8)
            }
            .tabItem { Text("Home") }
            .tag(0)

            Text("Offers")
                .tabItem { Text("Offers") }
                .tag(1)
        }
        .onChange(of: tab) { _, new in
            DiagnosticTaps.logSelectionChange(new == 0 ? "home" : "offers")
        }
    }
}

private enum ReportTouchError: Error {
    case missing(String)
}

private enum ReportTouchSynth {
    static func tap(at point: CGPoint, in window: UIWindow) throws {
        let touch = UITouch()
        try send(touch, phase: .began, at: point, in: window)
        RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        try send(touch, phase: .ended, at: point, in: window)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    static func drag(from start: CGPoint, to end: CGPoint, in window: UIWindow) throws {
        let touch = UITouch()
        try send(touch, phase: .began, at: start, in: window)
        let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
        try send(touch, phase: .moved, at: mid, in: window)
        try send(touch, phase: .ended, at: end, in: window)
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }

    private static func send(_ touch: UITouch, phase: UITouch.Phase, at point: CGPoint, in window: UIWindow) throws {
        let hit = window.hitTest(point, with: nil) ?? window
        try setObject(touch, "setWindow:", window)
        try setObject(touch, "setView:", hit)
        try setInt(touch, "setTapCount:", 1)
        try setInt(touch, "setPhase:", phase.rawValue)
        try setDouble(touch, "setTimestamp:", ProcessInfo.processInfo.systemUptime)
        try setLocation(touch, point, reset: phase == .began)
        let event = try touchesEvent()
        try clearTouches(event)
        try add(touch, to: event)
        UIApplication.shared.sendEvent(event)
    }

    private static func touchesEvent() throws -> UIEvent {
        let selector = NSSelectorFromString("_touchesEvent")
        guard UIApplication.shared.responds(to: selector) else {
            throw ReportTouchError.missing("_touchesEvent")
        }
        guard let unmanaged = UIApplication.shared.perform(selector) else {
            throw ReportTouchError.missing("_touchesEvent result")
        }
        guard let event = unmanaged.takeUnretainedValue() as? UIEvent else {
            throw ReportTouchError.missing("UIEvent")
        }
        return event
    }

    private static func clearTouches(_ event: UIEvent) throws {
        let selector = NSSelectorFromString("_clearTouches")
        guard (event as NSObject).responds(to: selector) else {
            throw ReportTouchError.missing("_clearTouches")
        }
        _ = (event as NSObject).perform(selector)
    }

    private static func add(_ touch: UITouch, to event: UIEvent) throws {
        let selector = NSSelectorFromString("_addTouch:forDelayedDelivery:")
        let object = event as NSObject
        guard object.responds(to: selector) else {
            throw ReportTouchError.missing("_addTouch:forDelayedDelivery:")
        }
        typealias Add = @convention(c) (AnyObject, Selector, UITouch, Bool) -> Void
        let function = unsafeBitCast(object.method(for: selector), to: Add.self)
        function(object, selector, touch, false)
    }

    private static func setLocation(_ touch: UITouch, _ point: CGPoint, reset: Bool) throws {
        let selector = NSSelectorFromString("_setLocationInWindow:resetPrevious:")
        guard touch.responds(to: selector) else {
            throw ReportTouchError.missing("_setLocationInWindow:resetPrevious:")
        }
        typealias SetLocation = @convention(c) (AnyObject, Selector, CGPoint, Bool) -> Void
        let function = unsafeBitCast(touch.method(for: selector), to: SetLocation.self)
        function(touch, selector, point, reset)
    }

    private static func setInt(_ object: NSObject, _ name: String, _ value: Int) throws {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { throw ReportTouchError.missing(name) }
        typealias SetInt = @convention(c) (AnyObject, Selector, Int) -> Void
        let function = unsafeBitCast(object.method(for: selector), to: SetInt.self)
        function(object, selector, value)
    }

    private static func setDouble(_ object: NSObject, _ name: String, _ value: Double) throws {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { throw ReportTouchError.missing(name) }
        typealias SetDouble = @convention(c) (AnyObject, Selector, Double) -> Void
        let function = unsafeBitCast(object.method(for: selector), to: SetDouble.self)
        function(object, selector, value)
    }

    private static func setObject(_ object: NSObject, _ name: String, _ value: AnyObject) throws {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { throw ReportTouchError.missing(name) }
        _ = object.perform(selector, with: value)
    }
}

private final class RemovingControl: UIControl {
    var onEnded: () -> Void = {}

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        onEnded()
        super.touchesEnded(touches, with: event)
    }
}

private final class ToggleCardHostingView: UIView {}
private final class KeyboardAvoidingPane: UIView {}

private struct InfoPlistBundle {
    let directory: URL
    let bundle: Bundle

    init(_ entries: [String: Any]) throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShakeReportPlist-\(UUID().uuidString).bundle", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var plist = entries
        plist["CFBundleIdentifier"] = "test.shake.report"
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: directory.appendingPathComponent("Info.plist"))
        bundle = try XCTUnwrap(Bundle(url: directory))
    }

    func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}
#endif
