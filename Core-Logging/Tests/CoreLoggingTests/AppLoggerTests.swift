import XCTest
@testable import CoreLogging

final class AppLoggerTests: XCTestCase {
    /// `writeToFile` forwards to the writer via a fire-and-forget `Task`, so tests need to
    /// yield briefly before inspecting the fake — the same pattern already used elsewhere in
    /// this codebase for fire-and-forget async work (e.g. `LoginViewModelTests`).
    private func settle() async {
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    func testErrorForwardsAFormattedLineToTheWriterWhenFileLoggingIsEnabled() async {
        let writer = FakeLogFileWriter()
        let logger = AppLogger(
            subsystem: "com.minit.test",
            category: "Networking",
            writer: writer,
            isFileLoggingEnabled: { true }
        )

        logger.error("Something failed")
        await settle()

        let lines = await writer.writtenLines
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("[ERROR]"), "Expected an ERROR tag in: \(lines[0])")
        XCTAssertTrue(lines[0].contains("com.minit.test/Networking"))
        XCTAssertTrue(lines[0].contains("Something failed"))
    }

    func testEachLogLevelTagsItsLineWithItsOwnLevel() async {
        let writer = FakeLogFileWriter()
        let logger = AppLogger(
            subsystem: "s",
            category: "c",
            writer: writer,
            isFileLoggingEnabled: { true }
        )

        logger.debug("d")
        logger.info("i")
        logger.warning("w")
        logger.error("e")
        await settle()

        let lines = await writer.writtenLines
        XCTAssertEqual(lines.count, 4)
        // Checked by count-of-matches rather than by index: the four calls each spawn their own
        // fire-and-forget `Task`, so arrival order at the writer isn't guaranteed.
        XCTAssertEqual(lines.filter { $0.contains("[DEBUG]") }.count, 1)
        XCTAssertEqual(lines.filter { $0.contains("[INFO]") }.count, 1)
        XCTAssertEqual(lines.filter { $0.contains("[WARNING]") }.count, 1)
        XCTAssertEqual(lines.filter { $0.contains("[ERROR]") }.count, 1)
    }

    func testNothingIsForwardedToTheWriterWhenFileLoggingIsDisabled() async {
        let writer = FakeLogFileWriter()
        let logger = AppLogger(
            subsystem: "s",
            category: "c",
            writer: writer,
            isFileLoggingEnabled: { false }
        )

        logger.error("should not be persisted")
        await settle()

        let lines = await writer.writtenLines
        XCTAssertTrue(lines.isEmpty)
    }

    func testErrorWritesFormattedErrorLineToARealFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppLoggerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let realWriter = LogFileWriter(directory: directory, isFileLoggingEnabled: { true })
        let didWrite = expectation(description: "AppLogger forwarded the error to LogFileWriter")
        let forwardingWriter = ExpectationForwardingWriter(
            writer: realWriter,
            didWrite: didWrite
        )
        let logger = AppLogger(
            subsystem: "com.minit.test",
            category: "Networking",
            writer: forwardingWriter,
            isFileLoggingEnabled: { true }
        )

        logger.error("Request failed")
        await fulfillment(of: [didWrite], timeout: 1)

        let fileURL = await realWriter.currentFileURL()
        let contents = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(contents.contains("[ERROR]"))
        XCTAssertTrue(contents.contains("com.minit.test/Networking"))
        XCTAssertTrue(contents.contains("Request failed"))
        XCTAssertTrue(contents.hasSuffix("\n"))
    }
}

private actor FakeLogFileWriter: LogFileWriting {
    private(set) var writtenLines: [String] = []

    func write(_ line: String) async {
        writtenLines.append(line)
    }
}

private actor ExpectationForwardingWriter: LogFileWriting {
    private let writer: LogFileWriter
    private let didWrite: XCTestExpectation

    init(writer: LogFileWriter, didWrite: XCTestExpectation) {
        self.writer = writer
        self.didWrite = didWrite
    }

    func write(_ line: String) async {
        await writer.write(line)
        didWrite.fulfill()
    }
}
