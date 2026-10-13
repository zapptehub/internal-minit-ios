import Foundation
import FirebaseAuth
import Sentry

/// Starts Sentry at launch and keeps its user in sync with Firebase Auth.
///
/// DEBUG-ONLY PRIVACY POLICY — MUST BE REVISITED BEFORE ANY PRODUCTION ENVIRONMENT EXISTS.
/// Only "development" and "internal" exist today, and both deliberately keep personal data
/// and auth tokens: no client-side scrubbing of Authorization headers, cookies or Firebase
/// ID tokens is added. Note: sentry-cocoa itself always strips Authorization/Cookie/
/// Set-Cookie and similar headers from failed-request (HTTP client error) events; that
/// filter is hard-coded with no option to disable it. Server-side Data Scrubber settings
/// live in the Sentry project settings, not here.
///
/// All environments send default PII (e.g. IP) and set the user to Firebase uid + email.
/// Screen capture is decided in one place, `screenCaptureEnvironments`:
/// - "internal" (Firebase App Distribution testers): screenshots, view hierarchy and
///   unmasked session replay (100%).
/// - Every other environment ("development"): no screenshots, view hierarchy or replay.
/// The DSN and environment come from Info.plist keys `SentryDSN` / `SentryEnvironment`,
/// filled from `Config/Sentry.xcconfig` (`SENTRY_DSN` / `SENTRY_ENVIRONMENT`).
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

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.releaseName = releaseName(bundle: bundle)
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

    /// Fallback when the Info.plist value is missing or unexpanded.
    static let defaultEnvironment = "development"

    /// `SENTRY_ENVIRONMENT` build setting ("development" locally, "internal" for
    /// Firebase App Distribution builds). Names live only in the xcconfig/build command.
    private static func environment(bundle: Bundle) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: "SentryEnvironment") as? String,
              !value.isEmpty, !value.hasPrefix("$(") else {
            return defaultEnvironment
        }
        return value
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
