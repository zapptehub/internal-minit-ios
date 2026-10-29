import Foundation
import FirebaseAuth
import Sentry

/// Starts Sentry at launch and keeps its user in sync with Firebase Auth.
///
/// Release (`MINIT_SENTRY_NO_PII` in `Config/Release.xcconfig`) sends no default
/// PII, no Firebase uid or email, and no HTTP query. Debug and Internal omit that
/// flag and keep all three. A later TestFlight configuration must omit the flag.
/// The choice is compile-time; there is no runtime switch.
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
/// Authorization is left in place. Those hooks do not add it. When `keepHttpQuery`
/// is false they clear `request.queryString` and breadcrumb `http.query`.
/// Server-side Data Scrubber settings live in the Sentry project settings, not here.
///
/// `SentryPiiPolicy` is `sendDefaultPii`, `attachUser` (uid and email together),
/// and `keepHttpQuery`. Non-release: all true. Release: all false.
/// The DSN and environment come from Info.plist keys `SentryDSN` / `SentryEnvironment`.
/// `SENTRY_DSN` is in `Config/Sentry.xcconfig`. `SENTRY_ENVIRONMENT` is set by
/// `Config/Development.xcconfig`, `Config/Internal.xcconfig`, and `Config/Release.xcconfig`.
nonisolated struct SentryPiiPolicy: Equatable, Sendable {
    let sendDefaultPii: Bool
    let attachUser: Bool
    let keepHttpQuery: Bool

    /// Debug and Internal. Also the policy a later TestFlight configuration uses.
    static let on = SentryPiiPolicy(sendDefaultPii: true, attachUser: true, keepHttpQuery: true)

    /// App Store Release, selected by `MINIT_SENTRY_NO_PII`.
    static let release = SentryPiiPolicy(sendDefaultPii: false, attachUser: false, keepHttpQuery: false)

    #if MINIT_SENTRY_NO_PII
    static let active = release
    #else
    static let active = on
    #endif
}

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

        #if MINIT_SENTRY_NO_PII
        authListener = Auth.auth().addStateDidChangeListener { _, _ in
            // `attachUser` is false. The function that would set uid and email is not in this build.
            guard SentryPiiPolicy.active.attachUser else { return }
        }
        #else
        authListener = Auth.auth().addStateDidChangeListener { _, user in
            guard SentryPiiPolicy.active.attachUser else { return }
            guard let user else {
                SentrySDK.setUser(nil)
                return
            }
            attachAuthenticatedUser(user)
        }
        #endif
    }

    #if !MINIT_SENTRY_NO_PII
    /// Sets Firebase uid and email on the Sentry user. Compiled out of Release.
    private static func attachAuthenticatedUser(_ user: FirebaseAuth.User) {
        let sentryUser = User(userId: user.uid)
        sentryUser.email = user.email
        SentrySDK.setUser(sentryUser)
    }
    #endif

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
        screenCapture: Bool,
        policy: SentryPiiPolicy = .active
    ) {
        options.dsn = dsn
        options.environment = environment
        options.releaseName = releaseName
        options.sendDefaultPii = policy.sendDefaultPii
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
        installCloudflareAccessSecretScrub(on: options, policy: policy)
    }

    /// Removes `CF-Access-Client-Secret` before a failed-request event or an HTTP
    /// breadcrumb is sent. Does not remove or add `Authorization` or `CF-Access-Client-Id`.
    /// When `keepHttpQuery` is false, clears `request.queryString` and breadcrumb `http.query`.
    private nonisolated static func installCloudflareAccessSecretScrub(
        on options: Options,
        policy: SentryPiiPolicy
    ) {
        options.beforeSend = { event in
            scrubCloudflareAccessClientSecret(from: event, policy: policy)
            return event
        }
        options.beforeBreadcrumb = { breadcrumb in
            scrubCloudflareAccessClientSecret(from: breadcrumb, policy: policy)
            return breadcrumb
        }
    }

    private nonisolated static let accessClientSecretHeader = "CF-Access-Client-Secret"

    private nonisolated static func isCloudflareAccessClientSecret(_ name: String) -> Bool {
        name.caseInsensitiveCompare(accessClientSecretHeader) == .orderedSame
    }

    private nonisolated static func scrubCloudflareAccessClientSecret(
        from event: Event,
        policy: SentryPiiPolicy
    ) {
        if !policy.keepHttpQuery {
            event.request?.queryString = nil
        }
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
        event.breadcrumbs?.forEach { scrubCloudflareAccessClientSecret(from: $0, policy: policy) }
    }

    private nonisolated static func scrubCloudflareAccessClientSecret(
        from breadcrumb: Breadcrumb,
        policy: SentryPiiPolicy
    ) {
        if !policy.keepHttpQuery {
            breadcrumb.setData(value: nil, key: "http.query")
        }
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
