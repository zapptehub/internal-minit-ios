import Foundation
import FirebaseAuth
import Sentry

/// Starts Sentry at launch and keeps its user in sync with Firebase Auth.
///
/// Privacy is decided in one place, `fullCaptureEnvironments`:
/// - Full capture ("internal", Firebase App Distribution testers): default PII,
///   screenshots, view hierarchy, unmasked session replay (100%), user = uid + email.
/// - Every other environment ("development"): no default PII, no screenshots, no view
///   hierarchy, no session replay; the only user identifier is the Firebase uid.
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
        let fullCapture = fullCaptureEnvironments.contains(environment)

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.releaseName = releaseName(bundle: bundle)
            options.sendDefaultPii = fullCapture
            options.attachScreenshot = fullCapture
            options.attachViewHierarchy = fullCapture
            options.sessionReplay.sessionSampleRate = fullCapture ? 1.0 : 0
            options.sessionReplay.onErrorSampleRate = fullCapture ? 1.0 : 0
            if fullCapture {
                options.sessionReplay.maskAllText = false
                options.sessionReplay.maskAllImages = false
            }
        }

        authListener = Auth.auth().addStateDidChangeListener { _, user in
            guard let user else {
                SentrySDK.setUser(nil)
                return
            }
            let sentryUser = User(userId: user.uid)
            if fullCapture {
                sentryUser.email = user.email
            }
            SentrySDK.setUser(sentryUser)
        }
    }

    /// Environments allowed to send everything (PII, screenshots, unmasked replay).
    /// The single switch for full capture: edit this set to change or rename it.
    static let fullCaptureEnvironments: Set<String> = ["internal"]

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
