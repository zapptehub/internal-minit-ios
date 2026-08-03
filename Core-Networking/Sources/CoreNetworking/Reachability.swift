import Foundation

/// Observes device network path reachability without performing requests.
///
/// Concrete monitors (e.g. App `PathReachability` backed by `NWPathMonitor`) live
/// outside this package so Core-Networking stays Foundation-only.
public protocol Reachability: Sendable {
    /// Latest known path status (`true` = satisfied).
    var isConnected: Bool { get }
    /// Emits on each update, including an immediate first value matching `isConnected`.
    var updates: AsyncStream<Bool> { get }
}
