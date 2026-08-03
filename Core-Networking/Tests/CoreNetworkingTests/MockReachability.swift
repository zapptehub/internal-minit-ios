import Foundation
import CoreNetworking

/// Controllable `Reachability` double for unit tests.
final class MockReachability: Reachability, @unchecked Sendable {
    private let lock = NSLock()
    private var connected: Bool
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    init(isConnected: Bool = true) {
        self.connected = isConnected
    }

    var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return connected
    }

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

    func simulateConnectionChange(_ isConnected: Bool) {
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
