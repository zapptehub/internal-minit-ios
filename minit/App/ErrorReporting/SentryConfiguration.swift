import Foundation
import FirebaseAuth
import Sentry

/// Starts Sentry at launch and keeps its user in sync with Firebase Auth.
///
/// TODO(Armands, before first Release ship): Release still sends PII and email.
/// WARNING: every environment, including "release", sets `sendDefaultPii = true`
/// and `sentryUser.email = user.email`. A Release build therefore sends the
/// customer's IP and Firebase email to Sentry. Whether a shipped Release build
/// may keep doing that is an open question for Armands. Decide it before the
/// first Release ship, and leave this behavior unchanged until that decision.
///
/// Environments are "development", "internal", and "release". Screen capture is
/// decided in one place, `screenCaptureEnvironments`:
/// - "internal" (Firebase App Distribution): screenshots, view hierarchy, and
///   unmasked session replay (100%).
/// - "development" and "release": no screenshots, view hierarchy, or replay.
///
/// When replay is on, personal data and auth tokens stay: no client-side scrubbing
/// of Authorization headers, cookies, or Firebase ID tokens is added. Replay
/// `networkRequestHeaders` is an allowlist and does not include `CF-Access-*`, so
/// replay does not record the Access secret. Internal replay still records
/// Authorization.
///
/// sentry-cocoa strips Authorization, Cookie, Set-Cookie, and similar headers from
/// failed-request (HTTP client error) events. That filter is hard-coded and does
/// not include `CF-Access-Client-Secret`. `beforeSend` removes that header from the
/// failed-request event (request headers, response headers, extras, and breadcrumbs
/// already on the event). `beforeBreadcrumb` removes it from breadcrumb data.
/// Authorization is left in place. Server-side Data Scrubber settings live in the
/// Sentry project settings, not here.
///
/// All environments send default PII (e.g. IP) and set the user to Firebase uid + email.
/// The DSN and environment come from Info.plist keys `SentryDSN` / `SentryEnvironment`.
/// `SENTRY_DSN` is in `Config/Sentry.xcconfig`. `SENTRY_ENVIRONMENT` is set by
/// `Config/Development.xcconfig`, `Config/Internal.xcconfig`, and `Config/Release.xcconfig`.
enum SentryConfiguration {
    private static var authListener: AuthStateDidChangeListenerHandle?

    static func start(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) {
        // The app is the unit-test host. Tests deliberately crash/stub HTTP 500s, which
        // would otherwise be reported as real issues (seen as MINIT-IOS-2 / MINIT-IOS-3).
        guard processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard let dsn = bundle.object(forInfoDictionaryKey: "SentryDSN") as? String,
              !dsn.isEmpty, !dsn.hasPrefix("$(") else {
            return
        }

        let environment = environment(bundle: bundle)
        let screenCapture = screenCaptureEnvironments.contains(environment)

        // `start` returns before this under XCTest. The failed-request test calls
        // `applyOptions`, which is the only place these options are assigned.
        SentrySDK.start { options in
            applyOptions(
                options,
                dsn: dsn,
                environment: environment,
                releaseName: releaseName(bundle: bundle),
                screenCapture: screenCapture
            )
        }

        authListener = Auth.auth().addStateDidChangeListener { _, user in
            guard let user else {
                SentrySDK.setUser(nil)
                return
            }
            let sentryUser = User(userId: user.uid)
            sentryUser.email = user.email
            SentrySDK.setUser(sentryUser)
        }
    }

    /// Environments allowed to capture the screen (screenshots, view hierarchy,
    /// unmasked session replay). The single switch: edit this set to change or rename it.
    static let screenCaptureEnvironments: Set<String> = ["internal"]

    /// Fallback when `SentryEnvironment` is missing or unexpanded.
    /// "development" is only the Debug fallback. Release and Internal use
    /// "unknown" so a failed expansion cannot be reported as development.
    #if DEBUG
    static let defaultEnvironment = "development"
    #else
    static let defaultEnvironment = "unknown"
    #endif

    /// `SentryEnvironment` from Info.plist, or `defaultEnvironment` when that
    /// value is missing or still unexpanded.
    private static func environment(bundle: Bundle) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: "SentryEnvironment") as? String,
              !value.isEmpty, !value.hasPrefix("$(") else {
            return defaultEnvironment
        }
        return value
    }

    /// Option setup shared by `start` and the failed-request scrub test.
    nonisolated static func applyOptions(
        _ options: Options,
        dsn: String,
        environment: String,
        releaseName: String?,
        screenCapture: Bool
    ) {
        options.dsn = dsn
        options.environment = environment
        options.releaseName = releaseName
        options.sendDefaultPii = true
        options.attachScreenshot = screenCapture
        options.attachViewHierarchy = screenCapture
        options.sessionReplay.sessionSampleRate = screenCapture ? 1.0 : 0
        options.sessionReplay.onErrorSampleRate = screenCapture ? 1.0 : 0
        if screenCapture {
            options.sessionReplay.maskAllText = false
            options.sessionReplay.maskAllImages = false
            // DEBUG-ONLY: keep auth tokens. Record headers (incl. Authorization, cookies,
            // Firebase ID tokens) and bodies of every request in the replay network tab.
            options.sessionReplay.networkDetailAllowUrls = ["http"] // substring: every URL
            options.sessionReplay.networkRequestHeaders = ["Authorization", "Cookie", "X-Firebase-AppCheck", "X-Client-Version", "X-Goog-Api-Key"]
            options.sessionReplay.networkResponseHeaders = ["Set-Cookie"]
        }
        installCloudflareAccessSecretScrub(on: options)
    }

    /// Removes `CF-Access-Client-Secret` before a failed-request event or an HTTP
    /// breadcrumb is sent. Does not remove `Authorization` or `CF-Access-Client-Id`.
    private nonisolated static func installCloudflareAccessSecretScrub(on options: Options) {
        options.beforeSend = { event in
            scrubCloudflareAccessClientSecret(from: event)
            return event
        }
        options.beforeBreadcrumb = { breadcrumb in
            scrubCloudflareAccessClientSecret(from: breadcrumb)
            return breadcrumb
        }
    }

    private nonisolated static let accessClientSecretHeader = "CF-Access-Client-Secret"

    private nonisolated static func isCloudflareAccessClientSecret(_ name: String) -> Bool {
        name.caseInsensitiveCompare(accessClientSecretHeader) == .orderedSame
    }

    private nonisolated static func scrubCloudflareAccessClientSecret(from event: Event) {
        if let headers = event.request?.headers {
            event.request?.headers = headers.filter { !isCloudflareAccessClientSecret($0.key) }
        }
        if let context = event.context {
            var scrubbed: [String: [String: Any]] = [:]
            for (key, value) in context where !isCloudflareAccessClientSecret(key) {
                scrubbed[key] = scrubbingStringKeyed(value)
            }
            event.context = scrubbed
        }
        if let extra = event.extra {
            event.extra = scrubbingStringKeyed(extra)
        }
        event.breadcrumbs?.forEach { scrubCloudflareAccessClientSecret(from: $0) }
    }

    private nonisolated static func scrubCloudflareAccessClientSecret(from breadcrumb: Breadcrumb) {
        guard let data = breadcrumb.data else { return }
        for (key, value) in data {
            if isCloudflareAccessClientSecret(key) {
                breadcrumb.setData(value: nil, key: key)
            } else if stringKeyedDictionary(value) != nil {
                breadcrumb.setData(value: scrubbingAny(value), key: key)
            }
        }
    }

    private nonisolated static func scrubbingStringKeyed(_ values: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in values where !isCloudflareAccessClientSecret(key) {
            result[key] = scrubbingAny(value)
        }
        return result
    }

    private nonisolated static func scrubbingAny(_ value: Any) -> Any {
        guard let dictionary = stringKeyedDictionary(value) else { return value }
        var result: [String: Any] = [:]
        for (key, nested) in dictionary where !isCloudflareAccessClientSecret(key) {
            result[key] = scrubbingAny(nested)
        }
        return result
    }

    private nonisolated static func stringKeyedDictionary(_ value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: String] {
            var result: [String: Any] = [:]
            for (key, nested) in dictionary {
                result[key] = nested
            }
            return result
        }
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        return nil
    }

    /// `<bundle id>@<short version>+<build>`, Sentry's recommended release format.
    private static func releaseName(bundle: Bundle) -> String? {
        let info = bundle.infoDictionary ?? [:]
        guard let id = bundle.bundleIdentifier,
              let version = info["CFBundleShortVersionString"] as? String else { return nil }
        let build = info["CFBundleVersion"] as? String ?? "0"
        return "\(id)@\(version)+\(build)"
    }
}
