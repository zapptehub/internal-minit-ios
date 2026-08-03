import XCTest
@testable import CoreNetworking

final class ReachabilityTests: XCTestCase {
    func testMock_updatesEmitsCurrentValueThenConnectionChange() async {
        let expectation = expectation(description: "network update received")
        let mock = MockReachability(isConnected: true)

        Task {
            for await isConnected in mock.updates {
                if !isConnected {
                    expectation.fulfill()
                    break
                }
            }
        }

        // Allow the subscriber to attach and receive the initial `true` before flipping.
        await Task.yield()
        mock.simulateConnectionChange(false)

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertFalse(mock.isConnected)
    }

    func testMock_isConnectedReflectsSimulatedChanges() {
        let mock = MockReachability(isConnected: true)
        XCTAssertTrue(mock.isConnected)

        mock.simulateConnectionChange(false)
        XCTAssertFalse(mock.isConnected)

        mock.simulateConnectionChange(true)
        XCTAssertTrue(mock.isConnected)
    }
}
