import XCTest
@testable import minit

@MainActor
final class RemoteConfigGateTests: XCTestCase {
    func testSecondReloadWhileInFlightIsIgnored() async {
        let blocking = snapshot(blocking: true, message: #"{"en":"Closed"}"#)
        let backend = ScriptedRemoteConfigBackend(snapshot: blocking)
        backend.holdReload = true
        let gate = makeGate(backend: backend)
        defer { backend.releaseReload() }

        gate.reloadMaintenance()
        await waitUntil { backend.reloadCount == 1 }

        XCTAssertTrue(gate.isReloadingMaintenance)
        gate.reloadMaintenance()
        XCTAssertEqual(backend.reloadCount, 1)

        backend.releaseReload()
        await waitUntil { !gate.isReloadingMaintenance }

        XCTAssertFalse(gate.isReloadingMaintenance)
        XCTAssertEqual(backend.reloadCount, 1)
        XCTAssertTrue(gate.showsMaintenanceStillUnavailableAlert)
        XCTAssertEqual(gate.snapshot, blocking)
    }

    func testSuccessfulReloadUsesActivatedSnapshot() async {
        let blocking = snapshot(blocking: true, message: #"{"en":"Closed"}"#)
        let activated = snapshot(blocking: false, minVersion: "9.0", softVersion: "8.0")
        let backend = ScriptedRemoteConfigBackend(snapshot: blocking)
        let gate = makeGate(backend: backend)
        backend.snapshot = activated

        gate.reloadMaintenance()
        await waitUntil { !gate.isReloadingMaintenance }

        XCTAssertFalse(gate.isReloadingMaintenance)
        XCTAssertEqual(gate.snapshot, activated)
        XCTAssertFalse(gate.showsMaintenanceStillUnavailableAlert)
    }

    func testFailedReloadIgnoresActivatedPayloadAndKeepsLiveSnapshot() async {
        let blocking = snapshot(blocking: true, message: #"{"en":"Closed"}"#)
        let backend = ScriptedRemoteConfigBackend(snapshot: blocking)
        backend.holdReload = true
        backend.reloadSucceeded = false
        let gate = makeGate(backend: backend)
        defer { backend.releaseReload() }

        gate.reloadMaintenance()
        await waitUntil { backend.reloadCount == 1 }
        backend.snapshot = snapshot(blocking: false, minVersion: "9.0")
        backend.releaseReload()
        await waitUntil { !gate.isReloadingMaintenance }

        XCTAssertEqual(gate.snapshot, blocking)
        XCTAssertTrue(gate.showsMaintenanceStillUnavailableAlert)
        XCTAssertFalse(gate.isReloadingMaintenance)
    }

    func testFailedReloadKeepsLiveSnapshotWhenMaintenanceClearsDuringFetch() async {
        let blocking = snapshot(blocking: true, message: #"{"en":"Closed"}"#)
        let cleared = snapshot(blocking: false, softVersion: "8.0")
        let backend = ScriptedRemoteConfigBackend(snapshot: blocking)
        backend.holdReload = true
        backend.reloadSucceeded = false
        let gate = makeGate(backend: backend)
        defer { backend.releaseReload() }

        gate.reloadMaintenance()
        await waitUntil { backend.reloadCount == 1 }

        backend.snapshot = cleared
        gate.foreground()
        XCTAssertEqual(backend.foregroundCount, 0, "foreground fetch must not overlap Reload")
        XCTAssertEqual(gate.snapshot, cleared)
        XCTAssertFalse(gate.showsMaintenanceStillUnavailableAlert)

        backend.snapshot = snapshot(blocking: true, message: #"{"en":"Nope"}"#, minVersion: "9.0")
        backend.releaseReload()
        await waitUntil { !gate.isReloadingMaintenance }

        XCTAssertEqual(gate.snapshot, cleared)
        XCTAssertFalse(gate.snapshot.maintenanceBlocking)
        XCTAssertFalse(gate.showsMaintenanceStillUnavailableAlert)
        XCTAssertFalse(gate.isReloadingMaintenance)
    }

    func testReloadWaitsForInFlightForegroundFetch() async {
        let blocking = snapshot(blocking: true, message: #"{"en":"Closed"}"#)
        let backend = ScriptedRemoteConfigBackend(snapshot: blocking)
        backend.holdForeground = true
        let gate = makeGate(backend: backend)
        defer { backend.releaseForeground() }

        gate.foreground()
        await waitUntil { backend.foregroundCount == 1 }

        gate.reloadMaintenance()
        gate.reloadMaintenance()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(gate.isReloadingMaintenance)
        XCTAssertEqual(backend.reloadCount, 0)
        XCTAssertEqual(backend.foregroundCount, 1)

        backend.snapshot = snapshot(blocking: false, minVersion: "9.0")
        backend.releaseForeground()
        await waitUntil { !gate.isReloadingMaintenance }

        XCTAssertEqual(backend.foregroundCount, 1)
        XCTAssertEqual(backend.reloadCount, 1)
        XCTAssertFalse(gate.isReloadingMaintenance)
        XCTAssertFalse(gate.snapshot.maintenanceBlocking)
        XCTAssertFalse(gate.showsMaintenanceStillUnavailableAlert)
    }

    func testStillUnavailableAlertClearsWhenMaintenanceEnds() async {
        let blocking = snapshot(blocking: true, message: #"{"en":"Closed"}"#)
        let backend = ScriptedRemoteConfigBackend(snapshot: blocking)
        let gate = makeGate(backend: backend)

        gate.reloadMaintenance()
        await waitUntil { !gate.isReloadingMaintenance }
        XCTAssertTrue(gate.showsMaintenanceStillUnavailableAlert)

        gate.acknowledgeMaintenanceStillUnavailable()
        XCTAssertFalse(gate.showsMaintenanceStillUnavailableAlert)

        gate.reloadMaintenance()
        await waitUntil { gate.showsMaintenanceStillUnavailableAlert }
        backend.snapshot = snapshot(blocking: false, softVersion: "8.0")
        gate.foreground()

        XCTAssertFalse(gate.snapshot.maintenanceBlocking)
        XCTAssertFalse(gate.showsMaintenanceStillUnavailableAlert)
    }

    func testReloadClearsInFlightFlagWhenFetchThrows() async {
        let blocking = snapshot(blocking: true, message: #"{"en":"Closed"}"#)
        let backend = ScriptedRemoteConfigBackend(snapshot: blocking)
        backend.reloadError = StubError()
        let gate = makeGate(backend: backend)

        gate.reloadMaintenance()
        await waitUntil { !gate.isReloadingMaintenance }

        XCTAssertFalse(gate.isReloadingMaintenance)
        XCTAssertEqual(backend.reloadCount, 1)
        XCTAssertEqual(gate.snapshot, blocking)
        XCTAssertTrue(gate.showsMaintenanceStillUnavailableAlert)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: () -> Bool
    ) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    private func makeGate(backend: ScriptedRemoteConfigBackend) -> RemoteConfigGate {
        let name = "RemoteConfigGateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return RemoteConfigGate(defaults: defaults, backend: backend)
    }

    private func snapshot(
        blocking: Bool,
        message: String = "{}",
        minVersion: String = "",
        softVersion: String = ""
    ) -> RemoteConfigSnapshot {
        RemoteConfigSnapshot(
            maintenanceBlocking: blocking,
            maintenanceBlockingMessage: message,
            maintenanceBannerMessage: "{}",
            maintenanceBannerStart: "",
            maintenanceBannerEnd: "",
            minVersionIOS: minVersion,
            softMinVersionIOS: softVersion,
            updateURLIOS: ""
        )
    }
}

@MainActor
private final class ScriptedRemoteConfigBackend: RemoteConfigBackend {
    var snapshot: RemoteConfigSnapshot
    var reloadSucceeded = true
    var reloadError: Error?
    var holdReload = false
    var holdForeground = false
    private(set) var reloadCount = 0
    private(set) var foregroundCount = 0
    private var reloadHold: CheckedContinuation<Void, Never>?
    private var foregroundHold: CheckedContinuation<Void, Never>?

    init(snapshot: RemoteConfigSnapshot) {
        self.snapshot = snapshot
    }

    func readSnapshot() -> RemoteConfigSnapshot { snapshot }

    func fetchAndActivate() async throws -> Bool {
        reloadCount += 1
        if holdReload {
            await withCheckedContinuation { reloadHold = $0 }
        }
        if let reloadError { throw reloadError }
        return reloadSucceeded
    }

    func fetchLatest() async throws {
        foregroundCount += 1
        if holdForeground {
            await withCheckedContinuation { foregroundHold = $0 }
        }
    }

    func releaseReload() {
        reloadHold?.resume()
        reloadHold = nil
    }

    func releaseForeground() {
        foregroundHold?.resume()
        foregroundHold = nil
    }
}

private struct StubError: Error {}
