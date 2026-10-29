#if MINIT_SHAKE
import Foundation
import FirebaseAuth
import UIKit

nonisolated enum ShakeReportGate {
    /// Empty, missing, or an unexpanded `$(...)` token is off. Any other string is the address.
    static func address(from raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value.hasPrefix("$(") { return nil }
        return value
    }

    /// False when there is no address, the alert or sheet is already up, or the
    /// shake that opened the alert was less than two seconds ago. A wall clock
    /// that moves backwards counts as elapsed so the cooldown cannot stick.
    static func shouldOpen(address: String?, busy: Bool, now: Date, lastShake: Date) -> Bool {
        guard address != nil, !busy else { return false }
        if now < lastShake { return true }
        return now.timeIntervalSince(lastShake) >= 2
    }
}

nonisolated enum ShakeReportScene {
    case active
    case inactive
    case background
}

nonisolated struct ShakeReportIdentity: Equatable, Sendable {
    var uid: String
    var email: String?
}

nonisolated struct ShakeReportContext: Equatable, Sendable {
    var version: String
    var build: String
    var environment: String
    var dataBackend: String
    var deviceModel: String
    var osVersion: String
    var languageCode: String

    @MainActor
    static func live(languageCode: String) -> (ShakeReportContext, ShakeReportIdentity?) {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let environment = expanded(bundle.object(forInfoDictionaryKey: "SentryEnvironment") as? String) ?? "unknown"
        let backend = expanded(bundle.object(forInfoDictionaryKey: "MinitDataBackend") as? String) ?? "firebase"
        let user = Auth.auth().currentUser
        let identity = user.map { ShakeReportIdentity(uid: $0.uid, email: $0.email) }
        let context = ShakeReportContext(
            version: version,
            build: build,
            environment: environment,
            dataBackend: backend,
            deviceModel: deviceModel(),
            osVersion: "iOS \(UIDevice.current.systemVersion)",
            languageCode: languageCode
        )
        return (context, identity)
    }

    private static func expanded(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value.hasPrefix("$(") { return nil }
        return value
    }

    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}

nonisolated enum ShakeReportRoute {
    static func screen(_ state: AppFlowViewModel.State) -> String {
        switch state {
        case .loading:
            return "loading"
        case .sessionRestoreFailed:
            return "sessionRestoreFailed"
        case .onboardingStatusFailed:
            return "onboardingStatusFailed"
        case .unauthenticated:
            return "unauthenticated"
        case .onboarding:
            return "onboarding"
        case .authenticated:
            return "authenticated"
        }
    }
}

nonisolated enum ShakeReportTime {
    static func text(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}

nonisolated enum ShakeReportScrub {
    static func line(_ text: String) -> String {
        var result = text
        result = replace(result, pattern: "(?i)authorization\\s*[:=]\\s*\\S+(?:\\s+\\S+)?", with: "")
        result = replace(result, pattern: "(?i)cookie\\s*[:=]\\s*\\S+", with: "")
        result = replace(result, pattern: "(?i)cf-access-client-secret\\s*[:=]\\s*\\S+", with: "")
        result = replace(result, pattern: "(?i)bearer\\s+\\S+", with: "Bearer [redacted]")
        result = replace(
            result,
            pattern: "[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}",
            with: "[redacted]"
        )
        result = replace(result, pattern: "/v1/loyalty-cards/[^/?#\\s]+", with: "/v1/loyalty-cards/[redacted]")
        result = dropQueryKeys(result)
        return result
    }

    static func path(of url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.path.isEmpty ? "/" : url.path
        }
        let path = components.percentEncodedPath.isEmpty ? "/" : components.percentEncodedPath
        guard let query = components.percentEncodedQuery, !query.isEmpty else { return path }
        components.query = nil
        return path + "?" + query
    }

    private static func replace(_ text: String, pattern: String, with template: String) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func dropQueryKeys(_ text: String) -> String {
        guard let queryStart = text.firstIndex(of: "?") else { return text }
        let head = text[..<queryStart]
        let rest = text[text.index(after: queryStart)...]
        let pieces = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let query = String(pieces[0])
        let tail = pieces.count > 1 ? " " + pieces[1] : ""
        let kept = query.split(separator: "&").filter { part in
            let name = part.split(separator: "=", maxSplits: 1).first.map(String.init)?.lowercased() ?? ""
            return name != "token" && name != "password" && name != "secret"
        }
        if kept.isEmpty {
            return String(head) + tail
        }
        return String(head) + "?" + kept.joined(separator: "&") + tail
    }
}

/// In-memory session log. Nothing here is written as the buffer; a kill drops it.
/// The clock is injectable so the 20-minute window can be tested without waiting.
nonisolated final class ShakeReportLog: @unchecked Sendable {
    static let shared = ShakeReportLog(enabled: false)

    static let window: TimeInterval = 20 * 60
    static let backgroundGrace: TimeInterval = 30

    private struct StoredLine {
        var time: Date
        var text: String
    }

    private enum Entry: Equatable {
        case none
        case getStarted
        case demoContinue
        case signedInForeground
    }

    private let clock: @Sendable () -> Date
    private let lock = NSLock()
    private var enabled: Bool
    private var lines: [StoredLine] = []
    private var entry: Entry = .none
    private var sessionStart: Date?
    private var foregroundAt: Date
    private var backgroundBegan: Date?
    private var suppressBackground = false

    init(clock: @escaping @Sendable () -> Date = Date.init, enabled: Bool = true) {
        self.clock = clock
        self.enabled = enabled
        self.foregroundAt = clock()
    }

    func setEnabled(_ enabled: Bool) {
        lock.lock()
        self.enabled = enabled
        lock.unlock()
    }

    var isEnabled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return enabled
    }

    func beginGetStarted() {
        mutate {
            guard enabled, entry == .none else { return }
            entry = .getStarted
            sessionStart = clock()
        }
    }

    /// Demo Continue replaces whatever session was open and drops its lines.
    func beginDemoContinue() {
        mutate {
            guard enabled else { return }
            lines.removeAll()
            entry = .demoContinue
            sessionStart = clock()
        }
    }

    func endSession() {
        mutate {
            guard enabled else { return }
            lines.removeAll()
            entry = .none
            sessionStart = nil
        }
    }

    /// Signed-in launch with no Get started or demo Continue. Lines already stored stay
    /// in memory and are left out of the file until they fall inside the foreground window.
    func noteSignedInLaunchIfNeeded() {
        mutate {
            guard enabled, entry == .none else { return }
            entry = .signedInForeground
        }
    }

    func scene(_ phase: ShakeReportScene) {
        mutate {
            guard enabled else { return }
            if suppressBackground {
                backgroundBegan = nil
                return
            }
            switch phase {
            case .inactive:
                break
            case .background:
                if backgroundBegan == nil {
                    backgroundBegan = clock()
                }
            case .active:
                guard let began = backgroundBegan else { return }
                backgroundBegan = nil
                let elapsed = clock().timeIntervalSince(began)
                if elapsed >= Self.backgroundGrace {
                    foregroundAt = clock()
                }
            }
        }
    }

    /// Mail and the share sheet stay in this scene on iOS. Ignore a background that
    /// still arrives while one of them is up, including one longer than 30 seconds.
    func beginExternalPresentation() {
        mutate {
            suppressBackground = true
            backgroundBegan = nil
        }
    }

    func endExternalPresentation() {
        mutate {
            suppressBackground = false
            backgroundBegan = nil
        }
    }

    func record(_ text: String) {
        let scrubbed = ShakeReportScrub.line(text)
        mutate {
            guard enabled else { return }
            let now = clock()
            lines.removeAll { now.timeIntervalSince($0.time) > Self.window }
            lines.append(StoredLine(time: now, text: scrubbed))
        }
    }

    func recordHTTP(method: String, url: URL?, status: Int, milliseconds: Int) {
        let path = url.map(ShakeReportScrub.path(of:)) ?? "/"
        record("\(method) \(path) \(status) \(milliseconds)ms")
    }

    func storedLineTexts() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return lines.map(\.text)
    }

    /// Rebuilds the file from the current session. Does not clear the buffer.
    func render(
        description: String,
        context: ShakeReportContext,
        identity: ShakeReportIdentity?
    ) -> String {
        lock.lock()
        let snapshot = Snapshot(
            lines: lines,
            entry: entry,
            sessionStart: sessionStart,
            foregroundAt: foregroundAt,
            now: clock()
        )
        lock.unlock()
        return snapshot.text(description: description, context: context, identity: identity)
    }

    private struct Snapshot {
        var lines: [StoredLine]
        var entry: Entry
        var sessionStart: Date?
        var foregroundAt: Date
        var now: Date

        func text(
            description: String,
            context: ShakeReportContext,
            identity: ShakeReportIdentity?
        ) -> String {
            let window = resolvedWindow()
            var header: [String] = [
                "version: \(context.version)",
                "build: \(context.build)",
                "environment: \(context.environment)",
                "data_backend: \(context.dataBackend)",
                "device: \(context.deviceModel)",
                "os: \(context.osVersion)",
                "language: \(context.languageCode)",
                "session_start: \(window.sessionStart)",
                "window_start: \(window.windowStart)",
                "window_minutes: \(window.minutes)",
                "cut_by_20min: \(window.cut)",
                "entry: \(window.entry)",
            ]
            if let identity {
                header.append("uid: \(identity.uid)")
                if let email = identity.email, !email.isEmpty {
                    header.append("email: \(email)")
                }
            }
            let body: String
            if window.entry == "none" {
                body = "session: none"
            } else if let start = window.includeFrom {
                body = lines
                    .filter { $0.time >= start && $0.time <= now }
                    .map(\.text)
                    .joined(separator: "\n")
            } else {
                body = ""
            }
            return header.joined(separator: "\n") + "\n\n" + description + "\n\n" + body
        }

        private struct Window {
            var sessionStart: String
            var windowStart: String
            var minutes: Int
            var cut: Bool
            var entry: String
            var includeFrom: Date?
        }

        private func resolvedWindow() -> Window {
            switch entry {
            case .none:
                return Window(
                    sessionStart: "none",
                    windowStart: "none",
                    minutes: 0,
                    cut: false,
                    entry: "none",
                    includeFrom: nil
                )
            case .getStarted, .demoContinue:
                let start = sessionStart ?? now
                let anchor = capped(start)
                return Window(
                    sessionStart: ShakeReportTime.text(start),
                    windowStart: ShakeReportTime.text(anchor.start),
                    minutes: anchor.minutes,
                    cut: anchor.cut,
                    entry: entry == .getStarted ? "get_started" : "demo_continue",
                    includeFrom: anchor.start
                )
            case .signedInForeground:
                let anchor = capped(foregroundAt)
                return Window(
                    sessionStart: ShakeReportTime.text(foregroundAt),
                    windowStart: ShakeReportTime.text(anchor.start),
                    minutes: anchor.minutes,
                    cut: anchor.cut,
                    entry: "signed_in_foreground",
                    includeFrom: anchor.start
                )
            }
        }

        private func capped(_ start: Date) -> (start: Date, minutes: Int, cut: Bool) {
            let cap = now.addingTimeInterval(-ShakeReportLog.window)
            if start < cap {
                return (cap, 20, true)
            }
            let minutes = Int(now.timeIntervalSince(start) / 60)
            return (start, minutes, false)
        }
    }

    private func mutate(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body()
    }
}
#endif
