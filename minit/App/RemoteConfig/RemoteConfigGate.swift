import Combine
import FirebaseRemoteConfig
import Foundation

/// Starts Remote Config immediately after `FirebaseApp.configure()`.
/// Defaults are applied before any fetch. The last activated values are applied next,
/// then `fetchAndActivate` runs without delaying first paint.
/// Foreground recomputes the banner window from the activated config and fetches again.
/// `minimumFetchInterval` is 0 on every channel. A failed fetch keeps the last activation.
@MainActor
final class RemoteConfigGate: ObservableObject {
    static let shared = RemoteConfigGate()

    @Published private(set) var snapshot = RemoteConfigSnapshot.defaults
    @Published private(set) var evaluatedAt = Date()
    @Published private(set) var dismissedBannerIdentity: String?

    private var remoteConfig: RemoteConfig?
    private var didStart = false
    /// Coalesces launch `activate` + the first foreground `.active` so they share one fetch.
    private var isFetching = false
    private let channel: AppDistributionChannel
    let installedMarketingVersion: String
    private let defaults: UserDefaults

    init(bundle: Bundle = .main, defaults: UserDefaults = .standard, now: Date = Date()) {
        let environment = bundle.object(forInfoDictionaryKey: "SentryEnvironment") as? String
        let fallback = AppDistributionChannel(rawValue: SentryConfiguration.defaultEnvironment) ?? .release
        channel = AppDistributionChannel.resolve(environment: environment, fallback: fallback)
        installedMarketingVersion = InstalledAppVersion.marketingVersion(bundle: bundle)
        self.defaults = defaults
        evaluatedAt = now
    }

    static func start() {
        shared.startIfNeeded()
    }

    func startIfNeeded() {
        guard !didStart else { return }
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        didStart = true

        let remoteConfig = RemoteConfig.remoteConfig()
        let settings = RemoteConfigSettings()
        settings.minimumFetchInterval = RemoteConfigFetchPolicy.minimumFetchInterval
        remoteConfig.configSettings = settings
        remoteConfig.setDefaults(RemoteConfigDefaults.firebaseValues)
        self.remoteConfig = remoteConfig
        snapshot = readSnapshot(from: remoteConfig)
        evaluatedAt = Date()

        remoteConfig.activate { _, _ in
            Task { @MainActor in
                RemoteConfigGate.shared.applyActivated()
                RemoteConfigGate.shared.fetchLatest()
            }
        }
    }

    /// Recomputes from the activated config, then fetches. The fetch respects `minimumFetchInterval`.
    func foreground() {
        guard didStart else { return }
        evaluatedAt = Date()
        if let remoteConfig {
            snapshot = readSnapshot(from: remoteConfig)
        }
        fetchLatest()
    }

    func decision(languageCode: String) -> AppVersionPolicy.Decision {
        AppVersionPolicy.evaluate(
            AppVersionPolicy.Input(
                snapshot: snapshot,
                channel: channel,
                installedMarketingVersion: installedMarketingVersion,
                languageCode: languageCode,
                now: evaluatedAt,
                dismissedSoftThreshold: defaults.string(forKey: AppVersionPolicy.dismissedSoftVersionDefaultsKey),
                dismissedBannerIdentity: dismissedBannerIdentity
            )
        )
    }

    func dismissBanner(identity: String) {
        dismissedBannerIdentity = identity
    }

    func dismissSoftUpdate(threshold: String) {
        defaults.set(threshold, forKey: AppVersionPolicy.dismissedSoftVersionDefaultsKey)
        objectWillChange.send()
    }

    private func fetchLatest() {
        guard let remoteConfig, !isFetching else { return }
        isFetching = true
        remoteConfig.fetchAndActivate { _, _ in
            Task { @MainActor in
                RemoteConfigGate.shared.isFetching = false
                RemoteConfigGate.shared.applyActivated()
            }
        }
    }

    private func applyActivated() {
        guard let remoteConfig else { return }
        snapshot = readSnapshot(from: remoteConfig)
        evaluatedAt = Date()
    }

    private func readSnapshot(from remoteConfig: RemoteConfig) -> RemoteConfigSnapshot {
        func string(_ key: String) -> String {
            remoteConfig.configValue(forKey: key).stringValue
        }
        return RemoteConfigSnapshot(
            maintenanceBlocking: remoteConfig.configValue(forKey: RemoteConfigKey.maintenanceBlocking).boolValue,
            maintenanceBlockingMessage: string(RemoteConfigKey.maintenanceBlockingMessage),
            maintenanceBannerMessage: string(RemoteConfigKey.maintenanceBannerMessage),
            maintenanceBannerStart: string(RemoteConfigKey.maintenanceBannerStart),
            maintenanceBannerEnd: string(RemoteConfigKey.maintenanceBannerEnd),
            minVersionIOS: string(RemoteConfigKey.minVersionIOS),
            softMinVersionIOS: string(RemoteConfigKey.softMinVersionIOS),
            updateURLIOS: string(RemoteConfigKey.updateURLIOS)
        )
    }
}
