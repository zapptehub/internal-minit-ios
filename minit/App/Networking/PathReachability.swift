import Foundation
import Network
import CoreNetworking

/// Abstracts `NWPathMonitor` so `PathReachability` can be unit-tested without real
/// radio / simulator networking. Production uses `NWPathObserver`; tests inject a fake.
protocol PathObserving: AnyObject {
    /// Snapshot of whether the current path is `.satisfied`.
    var isPathSatisfied: Bool { get }
    /// Invoked on the observer's start queue whenever the path status changes.
    var onPathChange: ((Bool) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func cancel()
}

/// Production `PathObserving` that wraps Apple's `NWPathMonitor`.
final class NWPathObserver: PathObserving {
    private let monitor = NWPathMonitor()

    var onPathChange: ((Bool) -> Void)?

    var isPathSatisfied: Bool {
        monitor.currentPath.status == .satisfied
    }

    func start(queue: DispatchQueue) {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.onPathChange?(path.status == .satisfied)
        }
        monitor.start(queue: queue)
    }

    func cancel() {
        monitor.cancel()
    }
}

/// App-owned `Reachability` backed by `NWPathMonitor` (via `PathObserving`).
///
/// Lives in the App target — same layering as `NetworkClientImpl` — so
/// Core-Networking stays Foundation-only and Features depend only on the
/// `Reachability` protocol.
///
/// `@unchecked Sendable` because mutable subscriber state is guarded by `lock`;
/// path callbacks arrive on `queue`, while `isConnected` / `updates` may be
/// read from any concurrent context.
final class PathReachability: Reachability, @unchecked Sendable {
    private let observer: PathObserving
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var connected: Bool
    /// Active `updates` subscribers — each gets the current value on subscribe,
    /// then every subsequent path change until the stream terminates.
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    /// - Parameters:
    ///   - observer: Path source; defaults to live `NWPathObserver`. Inject a fake in tests.
    ///   - queue: Queue on which path callbacks run (and where `NWPathMonitor` is started).
    init(
        observer: PathObserving = NWPathObserver(),
        queue: DispatchQueue = DispatchQueue(label: "minit.reachability")
    ) {
        self.observer = observer
        self.queue = queue
        // Seed from the observer's current path before starting — so `isConnected`
        // and the first `updates` yield are correct even before the first callback.
        self.connected = observer.isPathSatisfied

        observer.onPathChange = { [weak self] isConnected in
            self?.handlePathUpdate(isConnected)
        }
        observer.start(queue: queue)
    }

    deinit {
        observer.cancel()
        lock.lock()
        let active = Array(continuations.values)
        continuations.removeAll()
        lock.unlock()
        // Finish outside the lock. Skip if empty — finishing from `deinit` with no
        // subscribers is a no-op; with subscribers, end the streams so awaiters return.
        guard !active.isEmpty else { return }
        for continuation in active {
            continuation.finish()
        }
    }

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return connected
    }

    /// Yields the current connectivity immediately, then every path change.
    var updates: AsyncStream<Bool> {
        AsyncStream { continuation in
            let id = UUID()
            lock.lock()
            continuations[id] = continuation
            let current = connected
            lock.unlock()

            continuation.yield(current)
            continuation.onTermination = { [weak self] _ in
                self?.removeContinuation(id)
            }
        }
    }

    private func handlePathUpdate(_ isConnected: Bool) {
        lock.lock()
        connected = isConnected
        let active = Array(continuations.values)
        lock.unlock()

        for continuation in active {
            continuation.yield(isConnected)
        }
    }

    private func removeContinuation(_ id: UUID) {
        lock.lock()
        continuations[id] = nil
        lock.unlock()
    }
}
