import XCTest
@testable import minit

final class PathReachabilityTests: XCTestCase {
    private var retained: PathReachability?

    override func tearDown() {
        retained = nil
        super.tearDown()
    }

    func testIsConnected_seedsFromObserverBeforePathCallbacks() {
        let observer = FakePathObserver(isPathSatisfied: false)
        let reachability = PathReachability(
            observer: observer,
            queue: DispatchQueue(label: "minit.tests.reachability.seed")
        )
        retained = reachability

        XCTAssertFalse(reachability.isConnected)
        XCTAssertEqual(observer.startCallCount, 1)
    }

    func testUpdates_emitsCurrentValueThenConnectionChange() async {
        let expectation = expectation(description: "offline update received")
        let observer = FakePathObserver(isPathSatisfied: true)
        let reachability = PathReachability(
            observer: observer,
            queue: DispatchQueue(label: "minit.tests.reachability.updates")
        )
        retained = reachability

        Task {
            for await isConnected in reachability.updates {
                if !isConnected {
                    expectation.fulfill()
                    break
                }
            }
        }

        await Task.yield()
        observer.simulate(false)

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertFalse(reachability.isConnected)
    }

    func testIsConnected_tracksSimulatedPathChanges() {
        let observer = FakePathObserver(isPathSatisfied: true)
        let reachability = PathReachability(
            observer: observer,
            queue: DispatchQueue(label: "minit.tests.reachability.track")
        )
        retained = reachability

        XCTAssertTrue(reachability.isConnected)

        observer.simulate(false)
        XCTAssertFalse(reachability.isConnected)

        observer.simulate(true)
        XCTAssertTrue(reachability.isConnected)
    }
}

/// Controllable `PathObserving` double — no `NWPathMonitor` / radio involvement.
private final class FakePathObserver: PathObserving {
    var isPathSatisfied: Bool
    var onPathChange: ((Bool) -> Void)?
    private(set) var startCallCount = 0
    private(set) var cancelCallCount = 0

    init(isPathSatisfied: Bool) {
        self.isPathSatisfied = isPathSatisfied
    }

    func start(queue: DispatchQueue) {
        startCallCount += 1
    }

    func cancel() {
        cancelCallCount += 1
    }

    func simulate(_ isConnected: Bool) {
        isPathSatisfied = isConnected
        onPathChange?(isConnected)
    }
}
