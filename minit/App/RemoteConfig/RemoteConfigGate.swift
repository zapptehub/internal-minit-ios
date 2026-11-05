import Combine
@preconcurrency import FirebaseRemoteConfig
import Foundation

/// Fetch and activate surface used by the gate. Tests supply a stand-in; production uses Firebase.
@MainActor
protocol RemoteConfigBackend: AnyObject {
    func readSnapshot() -> RemoteConfigSnapshot
    /// `true` when the fetch succeeded. Activate is best-effort: "already activated" is not a failure.
    func fetchAndActivate() async throws -> Bool
    func fetchLatest() async throws
}

/// Starts Remote Config immediately after `FirebaseApp.configure()`.
/// Defaults are applied before any fetch. The last activated values are applied next,
/// then `fetchAndActivate` runs without delaying first paint.
/// Foreground recomputes the banner window from the activated config and fetches again.
/// `minimumFetchInterval` is 0 on every channel. A failed fetch keeps the live snapshot.
/// Launch, foreground, and maintenance Reload share one in-flight network fetch.
/// A rising edge of `maintenance_blocking` requests logout once per episode.
/// Force update, soft update, and the downtime banner do not.
@MainActor
final class RemoteConfigGate: ObservableObject {
    static let shared = RemoteConfigGate()

    @Published private(set) var snapshot = RemoteConfigSnapshot.defaults
    @Published private(set) var evaluatedAt = Date()
    @Published private(set) var dismissedBannerIdentity: String?
    /// True while a maintenance Reload fetch is in flight. A second tap is ignored.
    @Published private(set) var isReloadingMaintenance = false
    /// Native alert when Reload leaves blocking maintenance on.
    @Published private(set) var showsMaintenanceStillUnavailableAlert = false

    private var backend: (any RemoteConfigBackend)?
    private var didStart = false
    /// Coalesces launch, foreground, and Reload so only one network fetch runs.
    private var isFetching = false
    private var fetchWaiters: [CheckedContinuation<Void, Never>] = []
    private let channel: AppDistributionChannel
    let installedMarketingVersion: String
    private let defaults: UserDefaults
    /// Rising edge of blocking maintenance. Force, soft, and banner stay false.
    private var blockingLogoutEdge = BlockingMaintenanceLogoutEdge()
    /// Set when an episode begins before the app flow has registered a handler.
    private var pendingBlockingLogout = false
    private var blockingLogoutHandler: (@MainActor () -> Void)?

    init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard,
        now: Date = Date(),
        backend: (any RemoteConfigBackend)? = nil
    ) {
        let environment = bundle.object(forInfoDictionaryKey: "SentryEnvironment") as? String
        let fallback = AppDistributionChannel(rawValue: SentryConfiguration.defaultEnvironment) ?? .release
        channel = AppDistributionChannel.resolve(environment: environment, fallback: fallback)
        installedMarketingVersion = InstalledAppVersion.marketingVersion(bundle: bundle)
        self.defaults = defaults
        evaluatedAt = now
        if let backend {
            self.backend = backend
            didStart = true
            let initial = backend.readSnapshot()
            snapshot = initial
            noteBlockingLogout(initial)
        }
    }

    /// App flow registers the same logout the in-app Log Out control uses.
    /// A blocking episode that started before registration is delivered once, here.
    func bindBlockingLogoutHandler(_ handler: @escaping @MainActor () -> Void) {
        blockingLogoutHandler = handler
        deliverPendingBlockingLogout()
    }

    /// True once, when a blocking episode requested logout and no handler has run it.
    /// Bootstrap consumes this so it does not restore a session under the sheet.
    func consumePendingBlockingLogout() -> Bool {
        guard pendingBlockingLogout else { return false }
        pendingBlockingLogout = false
        return true
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
        let backend = FirebaseRemoteConfigBackend(remoteConfig: remoteConfig)
        self.backend = backend
        publish(backend.readSnapshot())

        RemoteConfigFirebaseFetch.activateCached(remoteConfig) {
            Task { @MainActor in
                RemoteConfigGate.shared.applyActivated()
                RemoteConfigGate.shared.fetchLatest()
            }
        }
    }

    /// Recomputes from the activated config, then fetches. The fetch respects `minimumFetchInterval`.
    func foreground() {
        guard didStart else { return }
        if let backend {
            publish(backend.readSnapshot())
        } else {
            evaluatedAt = Date()
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

    func acknowledgeMaintenanceStillUnavailable() {
        showsMaintenanceStillUnavailableAlert = false
    }

    /// Fetches Remote Config from the backend and activates it, then recomputes the gate.
    /// Waits until an in-flight foreground fetch finishes so the two do not overlap.
    /// Maintenance off dismisses the sheet through the normal decision. Still blocking,
    /// including a failed fetch whose live snapshot is still blocking, shows the native alert.
    /// A failed fetch keeps that live snapshot, not the values from when Reload was tapped.
    func reloadMaintenance() {
        guard !isReloadingMaintenance else { return }
        isReloadingMaintenance = true
        Task { @MainActor in
            defer { self.isReloadingMaintenance = false }
            await self.waitUntilFetchSettles()
            let succeeded = await self.reloadFetch()
            self.finishMaintenanceReload(fetchSucceeded: succeeded)
        }
    }

    private func finishMaintenanceReload(fetchSucceeded: Bool) {
        let live = snapshot
        let activated = backend?.readSnapshot() ?? live
        let resolution = AppVersionPolicy.resolveMaintenanceReload(
            fetchSucceeded: fetchSucceeded,
            activated: activated,
            cached: live
        )
        publish(resolution.snapshot)
        showsMaintenanceStillUnavailableAlert = resolution.outcome == .stillUnavailable
    }

    /// Suspends while a foreground or Reload fetch is in flight. The check and the
    /// waiter registration stay on the main actor, so the fetch cannot finish between them.
    private func waitUntilFetchSettles() async {
        guard isFetching else { return }
        await withCheckedContinuation { continuation in
            fetchWaiters.append(continuation)
        }
    }

    private func reloadFetch() async -> Bool {
        guard let backend else { return false }
        isFetching = true
        defer { self.endNetworkFetch() }
        do {
            return try await backend.fetchAndActivate()
        } catch {
            return false
        }
    }

    private func fetchLatest() {
        guard let backend, !isFetching, !isReloadingMaintenance else { return }
        isFetching = true
        Task { @MainActor in
            defer { self.endNetworkFetch() }
            try? await backend.fetchLatest()
            self.applyActivated()
        }
    }

    private func endNetworkFetch() {
        isFetching = false
        let waiters = fetchWaiters
        fetchWaiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func applyActivated() {
        guard let backend else { return }
        publish(backend.readSnapshot())
    }

    /// Publishing a non-blocking snapshot drops the still-unavailable alert. The sheet
    /// can disappear without the OK handler, and the next maintenance episode must not
    /// show that alert on its own.
    /// Blocking maintenance requests logout on the rising edge only, after the snapshot
    /// is visible to the handler.
    private func publish(_ snapshot: RemoteConfigSnapshot) {
        self.snapshot = snapshot
        evaluatedAt = Date()
        if !snapshot.maintenanceBlocking {
            showsMaintenanceStillUnavailableAlert = false
        }
        noteBlockingLogout(snapshot)
    }

    private func noteBlockingLogout(_ snapshot: RemoteConfigSnapshot) {
        guard blockingLogoutEdge.observe(isBlocking: snapshot.maintenanceBlocking) else { return }
        pendingBlockingLogout = true
        deliverPendingBlockingLogout()
    }

    private func deliverPendingBlockingLogout() {
        guard pendingBlockingLogout, let blockingLogoutHandler else { return }
        pendingBlockingLogout = false
        blockingLogoutHandler()
    }
}

/// Firebase calls these completions off the main actor. The methods are nonisolated so
/// the callbacks are not MainActor-isolated under the app's default actor isolation.
private enum RemoteConfigFirebaseFetch {
    nonisolated static func fetchAndActivate(_ remoteConfig: RemoteConfig, expiration: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            remoteConfig.fetch(withExpirationDuration: expiration) { status, error in
                let fetched = error == nil && status == .success
                guard fetched else {
                    continuation.resume(returning: false)
                    return
                }
                // "Already activated" completes with changed == false and a nil error.
                // That is not a fetch failure. Any other activate error is ignored;
                // the gate re-reads whatever config is active.
                remoteConfig.activate { _, _ in
                    continuation.resume(returning: true)
                }
            }
        }
    }

    nonisolated static func fetchLatest(_ remoteConfig: RemoteConfig) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            remoteConfig.fetchAndActivate { _, _ in
                continuation.resume()
            }
        }
    }

    nonisolated static func activateCached(
        _ remoteConfig: RemoteConfig,
        completion: @escaping @Sendable () -> Void
    ) {
        remoteConfig.activate { _, _ in
            completion()
        }
    }
}

@MainActor
private final class FirebaseRemoteConfigBackend: RemoteConfigBackend {
    private let remoteConfig: RemoteConfig

    init(remoteConfig: RemoteConfig) {
        self.remoteConfig = remoteConfig
    }

    func readSnapshot() -> RemoteConfigSnapshot {
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

    func fetchAndActivate() async throws -> Bool {
        let expiration = RemoteConfigFetchPolicy.minimumFetchInterval
        return await RemoteConfigFirebaseFetch.fetchAndActivate(remoteConfig, expiration: expiration)
    }

    func fetchLatest() async throws {
        await RemoteConfigFirebaseFetch.fetchLatest(remoteConfig)
    }
}
