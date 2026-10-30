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
    /// UTC `2026-10-29T19:44:18Z` for the report header.
    static func text(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    /// `+02:00` for the report header. Line stamps stay on `localClock` and are not rewritten.
    static func zoneOffset(_ date: Date, timeZone: TimeZone) -> String {
        let seconds = timeZone.secondsFromGMT(for: date)
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        return String(format: "%@%02d:%02d", sign, absolute / 3600, (absolute % 3600) / 60)
    }

    /// Local wall clock `21:44:18.123` for one log line. Header timestamps stay on `text`.
    static func localClock(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        var hour = parts.hour ?? 0
        var minute = parts.minute ?? 0
        var second = parts.second ?? 0
        // `Date` does not store decimal milliseconds exactly. Round, and carry 1000ms.
        var millis = Int((Double(parts.nanosecond ?? 0) / 1_000_000).rounded())
        if millis >= 1000 {
            millis = 0
            second += 1
            if second >= 60 {
                second = 0
                minute += 1
                if minute >= 60 {
                    minute = 0
                    hour = (hour + 1) % 24
                }
            }
        }
        return String(format: "%02d:%02d:%02d.%03d", hour, minute, second, millis)
    }
}

nonisolated enum ShakeReportScrub {
    /// `_` and `-` are ignored, so `idToken`, `id_token`, and `Set-Cookie` compare equal.
    static func normalizedKey(_ key: String) -> String {
        String(key.lowercased().filter { $0 != "_" && $0 != "-" })
    }

    /// Object keys. `code` is not listed: a loyalty-card code and an API error code share that name,
    /// and the body logger decides from the value. Query strings drop `code` unconditionally.
    ///
    /// `token` is exact, plus credential names such as `accessToken`. A bare contains-check would
    /// also hide `backgroundToken`, which is a home banner color.
    static func isSensitiveJSONKey(_ key: String) -> Bool {
        let normalized = normalizedKey(key)
        if normalized == "ean" || normalized == "loyaltycardid" || normalized == "sig" {
            return true
        }
        if normalized.contains("signature") { return true }
        if credentialTokenKeys.contains(normalized) { return true }
        if credentialTokenKeys.contains(where: { $0 != "token" && normalized.contains($0) }) {
            return true
        }
        return jsonKeyNeedles.contains { normalized.contains($0) }
    }

    static func line(_ text: String) -> String {
        var result = text
        result = replace(result, pattern: "(?i)authorization\\s*[:=]\\s*\\S+(?:\\s+\\S+)?", with: "")
        result = replace(result, pattern: "(?i)cookie\\s*[:=]\\s*\\S+", with: "")
        result = replace(result, pattern: "(?i)cf-access-client-secret\\s*[:=]\\s*\\S+", with: "")
        result = scrubSecrets(in: result)
        return dropQueryKeys(result)
    }

    /// JWT, `Bearer …`, and loyalty-card paths. Does not drop query keys; `line` always does,
    /// and body strings do only when the value is a URL.
    static func scrubSecrets(in text: String) -> String {
        var result = text
        result = replace(result, pattern: "(?i)bearer\\s+\\S+", with: "Bearer [redacted]")
        result = replace(
            result,
            pattern: "[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}\\.[A-Za-z0-9_-]{8,}",
            with: "[redacted]"
        )
        result = replace(result, pattern: "/v1/loyalty-cards/[^/?#\\s\"]+", with: "/v1/loyalty-cards/[redacted]")
        return result
    }

    /// Exact credential names. `x-access-token` normalises to a string that contains `accesstoken`.
    private static let credentialTokenKeys: Set<String> = [
        "token", "accesstoken", "refreshtoken", "idtoken", "authtoken",
        "sessiontoken", "customtoken", "fcmtoken", "pushtoken", "bearertoken",
    ]

    /// `cookies` matches `cookie`, `passwords` matches `password`. `token` is not in this list.
    private static let jsonKeyNeedles = [
        "password", "passwd", "secret", "authorization", "cookie",
        "barcode", "cardcode", "cardnumber", "apikey", "qrcode", "otp", "verificationcode",
    ]

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

    static func dropQueryKeys(_ text: String) -> String {
        guard let queryStart = text.firstIndex(of: "?") else { return text }
        let head = text[..<queryStart]
        let rest = text[text.index(after: queryStart)...]
        let pieces = rest.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let query = String(pieces[0])
        let tail = pieces.count > 1 ? " " + pieces[1] : ""
        let kept = query.split(separator: "&").filter { part in
            let raw = part.split(separator: "=", maxSplits: 1).first.map(String.init) ?? ""
            let name = raw.removingPercentEncoding ?? raw
            return !isSensitiveQueryName(name)
        }
        if kept.isEmpty {
            return String(head) + tail
        }
        return String(head) + "?" + kept.joined(separator: "&") + tail
    }

    /// Same names as a JSON key, plus `code` and `key`. `access_token` contains `token`.
    /// `X-Amz-Signature` contains `signature`. `sig` is exact so `sign` stays.
    private static func isSensitiveQueryName(_ name: String) -> Bool {
        let normalized = normalizedKey(name)
        if normalized == "code" || normalized == "key" { return true }
        return isSensitiveJSONKey(name)
    }
}

/// One response body for the session log.
///
/// JSON, including JSON sent as `text/*` or with no content type, is minified.
/// Sensitive keys become `***` at any depth. A `code` string is kept when it is a
/// symbolic error code (letters and underscores only) and becomes `***` otherwise,
/// which is how loyalty-card codes are removed. `uid` and `email` stay.
///
/// This does not call `ShakeReportScrub.line`: that helper is for whole log lines.
/// String values use the shared JWT, bearer, and loyalty-card helpers. A value that
/// is itself JSON is parsed and scrubbed again.
///
/// Anything that is not JSON, and any body over `maxCaptureBytes`, is logged as the
/// content type and size. An empty body is `empty`. Release builds do not compile this.
nonisolated enum ShakeReportBody {
    static let maxBytes = 2048
    static let maxCaptureBytes = 256 * 1024
    /// JSONSerialization and the scrub walk both stop here. Deeper input is not parsed.
    private static let maxDepth = 64

    static func line(data: Data, contentType: String?) -> String {
        if data.isEmpty { return "empty" }
        let media = mediaType(contentType)
        if data.count > maxCaptureBytes {
            return sizeLine(media ?? "application/octet-stream", count: data.count, captured: false)
        }
        switch classification(of: contentType) {
        case .json:
            return jsonLine(data) ?? sizeLine(media ?? "application/json", count: data.count)
        case .text:
            return jsonLine(data) ?? sizeLine(media ?? "text/plain", count: data.count)
        case .binary(let type):
            return sizeLine(type, count: data.count)
        case .unspecified:
            if let json = jsonLine(data) { return json }
            if String(data: data, encoding: .utf8) != nil {
                return sizeLine("text/plain", count: data.count)
            }
            return sizeLine("application/octet-stream", count: data.count)
        }
    }

    private static func sizeLine(_ type: String, count: Int, captured: Bool = true) -> String {
        captured ? "\(type) \(count) bytes" : "\(type) \(count) bytes (not captured)"
    }

    private enum Classification {
        case json
        case text
        case binary(String)
        case unspecified
    }

    private static func classification(of contentType: String?) -> Classification {
        guard let media = mediaType(contentType) else { return .unspecified }
        if media == "application/json" || media == "text/json" || media.hasSuffix("+json") {
            return .json
        }
        if media.hasPrefix("text/") {
            return .text
        }
        return .binary(media)
    }

    private static func mediaType(_ contentType: String?) -> String? {
        guard let contentType else { return nil }
        let media = contentType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() } ?? ""
        return media.isEmpty ? nil : media
    }

    private static func jsonLine(_ data: Data) -> String? {
        if nestingExceedsLimit(data) { return nil }
        guard let value = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        let scrubbed = scrub(value, depth: 0)
        guard var text = encodeAny(scrubbed) else { return nil }
        text = redactLoyaltyCardPaths(text)
        return truncated(text)
    }

    /// A `code` value made of letters and underscores is an API error code (`not_found`).
    /// Anything else under that key, including `MINIT-CONTRACT1`, is a card code.
    private static func looksLikeCardCode(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        let symbolic = trimmed.lowercased()
        return symbolic.range(of: #"^[a-z][a-z_]{0,63}$"#, options: .regularExpression) == nil
    }

    /// Stops at `"` so the rest of a compact JSON line, including `email`, stays.
    private static func redactLoyaltyCardPaths(_ text: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: "/v1/loyalty-cards/[^/?#\\s\"]+"
        ) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "/v1/loyalty-cards/[redacted]"
        )
    }

    private static func scrub(_ value: Any, depth: Int) -> Any {
        if depth >= maxDepth { return "***" }
        if let dictionary = value as? [String: Any] {
            var copy: [String: Any] = [:]
            copy.reserveCapacity(dictionary.count)
            for (key, nested) in dictionary {
                copy[key] = scrubbedField(key: key, value: nested, depth: depth)
            }
            return copy
        }
        if let array = value as? [Any] {
            return array.map { scrub($0, depth: depth + 1) }
        }
        if let string = value as? String {
            return scrubString(string, depth: depth)
        }
        return value
    }

    private static func scrubbedField(key: String, value: Any, depth: Int) -> Any {
        if ShakeReportScrub.normalizedKey(key) == "code" {
            if let string = value as? String {
                return looksLikeCardCode(string) ? "***" : scrubString(string, depth: depth + 1)
            }
            return scrub(value, depth: depth + 1)
        }
        if ShakeReportScrub.isSensitiveJSONKey(key) { return "***" }
        return scrub(value, depth: depth + 1)
    }

    private static func scrubString(_ string: String, depth: Int) -> String {
        if depth < 4, let parsed = reparsedJSON(string, depth: depth) {
            return parsed
        }
        var result = ShakeReportScrub.scrubSecrets(in: string)
        if result.contains("?"), result.contains("://") || result.contains("/v1/") {
            result = ShakeReportScrub.dropQueryKeys(result)
        }
        return result
    }

    /// A string value that is itself a JSON object or array. Nil when it is not.
    private static func reparsedJSON(_ string: String, depth: Int) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
              let data = trimmed.data(using: .utf8),
              !nestingExceedsLimit(data),
              let nested = try? JSONSerialization.jsonObject(with: data),
              let encoded = encodeObject(scrub(nested, depth: depth + 1)) else {
            return nil
        }
        return encoded
    }

    /// Top-level strings, numbers, and `null` are encoded here. Falling through to the
    /// raw bytes would log a token that arrived as a JSON string.
    private static func encodeAny(_ value: Any) -> String? {
        if value is NSNull { return "null" }
        if value is String || value is NSNumber {
            return encodeFragment(value)
        }
        return encodeObject(value)
    }

    private static func encodeObject(_ value: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(value),
              let encoded = try? JSONSerialization.data(
                withJSONObject: value,
                options: [.withoutEscapingSlashes, .sortedKeys]
              ),
              let text = String(data: encoded, encoding: .utf8) else {
            return nil
        }
        return text
    }

    private static func encodeFragment(_ value: Any) -> String? {
        guard let encoded = try? JSONSerialization.data(
            withJSONObject: [value],
            options: [.withoutEscapingSlashes]
        ),
              var text = String(data: encoded, encoding: .utf8),
              text.hasPrefix("["), text.hasSuffix("]") else {
            return nil
        }
        text.removeFirst()
        text.removeLast()
        return text
    }

    /// Counts brackets outside strings so a nested payload cannot blow the parser stack.
    private static func nestingExceedsLimit(_ data: Data) -> Bool {
        var depth = 0
        var inString = false
        var escaped = false
        for byte in data {
            if inString {
                if escaped {
                    escaped = false
                } else if byte == UInt8(ascii: "\\") {
                    escaped = true
                } else if byte == UInt8(ascii: "\"") {
                    inString = false
                }
                continue
            }
            switch byte {
            case UInt8(ascii: "\""):
                inString = true
            case UInt8(ascii: "{"), UInt8(ascii: "["):
                depth += 1
                if depth > maxDepth { return true }
            case UInt8(ascii: "}"), UInt8(ascii: "]"):
                if depth > 0 { depth -= 1 }
            default:
                break
            }
        }
        return false
    }

    private static func truncated(_ text: String) -> String {
        let bytes = Data(text.utf8)
        guard bytes.count > maxBytes else { return text }
        var end = maxBytes
        while end > 0, bytes[end] & 0b1100_0000 == 0b1000_0000 {
            end -= 1
        }
        let prefix = String(decoding: bytes.prefix(end), as: UTF8.self)
        let cut = bytes.count - end
        return prefix + "…(truncated \(cut) bytes)"
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
        /// Local `HH:mm:ss.SSS` captured with the line, so a later zone change does not rewrite it.
        var stamp: String
    }

    private enum Entry: Equatable {
        case none
        case getStarted
        case demoContinue
        case signedInForeground
    }

    private let clock: @Sendable () -> Date
    private let timeZone: @Sendable () -> TimeZone
    private let lock = NSLock()
    private var enabled: Bool
    private var lines: [StoredLine] = []
    private var entry: Entry = .none
    private var sessionStart: Date?
    private var foregroundAt: Date
    private var backgroundBegan: Date?
    private var suppressBackground = false

    init(
        clock: @escaping @Sendable () -> Date = Date.init,
        timeZone: @escaping @Sendable () -> TimeZone = { .current },
        enabled: Bool = true
    ) {
        self.clock = clock
        self.timeZone = timeZone
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
        store([ShakeReportScrub.line(singleLine(text))])
    }

    /// Request line, then the response body, both stamped at the same moment.
    /// The body is formatted before the append, so the pair stays adjacent.
    /// Body text is not passed through `ShakeReportScrub.line`.
    func recordHTTP(
        method: String,
        url: URL?,
        status: Int,
        milliseconds: Int,
        body: Data,
        contentType: String?
    ) {
        guard isEnabled else { return }
        let path = url.map(ShakeReportScrub.path(of:)) ?? "/"
        let requestLine = ShakeReportScrub.line("\(method) \(path) \(status) \(milliseconds)ms")
        let bodyLine = ShakeReportBody.line(data: body, contentType: contentType)
        store([requestLine, bodyLine])
    }

    private func singleLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }

    private func store(_ texts: [String]) {
        let stored = texts.map { singleLine($0) }
        mutate {
            guard enabled else { return }
            let now = clock()
            let stamp = ShakeReportTime.localClock(now, timeZone: timeZone())
            lines.removeAll { now.timeIntervalSince($0.time) > Self.window }
            for text in stored {
                lines.append(StoredLine(time: now, text: text, stamp: stamp))
            }
        }
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
            now: clock(),
            timeZone: timeZone()
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
        var timeZone: TimeZone

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
                "tz: \(ShakeReportTime.zoneOffset(now, timeZone: timeZone))",
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
                    .map { "\($0.stamp) \($0.text)" }
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
