import XCTest
@testable import CoreLogging

final class LoggingConfigurationTests: XCTestCase {
    override func tearDown() {
        // `LoggingConfiguration` is process-global state; reset it so other tests (in this
        // target or, if ever linked together, elsewhere) don't observe a value this test left
        // behind.
        LoggingConfiguration.configure(fileLoggingEnabled: false)
        super.tearDown()
    }

    func testFileLoggingIsDisabledByDefault() {
        XCTAssertFalse(LoggingConfiguration.fileLoggingEnabled)
    }

    func testConfigureEnablesFileLogging() {
        LoggingConfiguration.configure(fileLoggingEnabled: true)

        XCTAssertTrue(LoggingConfiguration.fileLoggingEnabled)
    }

    func testConfigureCanDisableFileLoggingAfterEnablingIt() {
        LoggingConfiguration.configure(fileLoggingEnabled: true)

        LoggingConfiguration.configure(fileLoggingEnabled: false)

        XCTAssertFalse(LoggingConfiguration.fileLoggingEnabled)
    }
}
