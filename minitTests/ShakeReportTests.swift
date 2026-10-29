import CoreLogging
import CoreNetworking
import DesignSystem
import XCTest
@testable import minit

#if MINIT_SHAKE
final class ShakeReportTests: XCTestCase {
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

        let lines = log.storedLineTexts().filter { $0.hasPrefix("GET /v1/shake-probe ") }
        XCTAssertEqual(lines.count, 2)
        assertHTTPLine(lines[0], method: "GET", path: "/v1/shake-probe", status: 401)
        assertHTTPLine(lines[1], method: "GET", path: "/v1/shake-probe", status: 200)
        let blob = lines.joined(separator: "\n")
        XCTAssertFalse(blob.contains("fake-token"))
        XCTAssertFalse(blob.contains("first-body"))
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

private struct ShakeHTTPProbe: Decodable {
    let id: Int
}

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
