import XCTest
@testable import CoreLogging

final class LogFileWriterTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LogFileWriterTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        try super.tearDownWithError()
    }

    private func contentsOfCurrentLogFile(_ writer: LogFileWriter) async throws -> String {
        let url = await writer.currentFileURL()
        return try String(contentsOf: url, encoding: .utf8)
    }

    // MARK: - write(_:)

    func testWriteAppendsLineFollowedByNewlineToTheFileOnDisk() async throws {
        let writer = LogFileWriter(directory: tempDirectory, isFileLoggingEnabled: { true })

        await writer.write("2026-01-01T00:00:00Z [ERROR] app/Networking — request failed")

        let contents = try await contentsOfCurrentLogFile(writer)
        XCTAssertEqual(contents, "2026-01-01T00:00:00Z [ERROR] app/Networking — request failed\n")
    }

    func testMultipleWritesAppendInCallOrderRatherThanOverwriting() async throws {
        let writer = LogFileWriter(directory: tempDirectory, isFileLoggingEnabled: { true })

        await writer.write("first line")
        await writer.write("second line")
        await writer.write("third line")

        let contents = try await contentsOfCurrentLogFile(writer)
        XCTAssertEqual(contents, "first line\nsecond line\nthird line\n")
    }

    func testWriteIsANoOpWhenFileLoggingIsDisabled() async throws {
        let writer = LogFileWriter(directory: tempDirectory, isFileLoggingEnabled: { false })

        await writer.write("should not be persisted")

        let contents = try await contentsOfCurrentLogFile(writer)
        XCTAssertEqual(contents, "")
    }

    // MARK: - currentFileURL / allLogFileURLs

    func testCurrentFileURLIsALogFileInsideTheGivenDirectory() async {
        let writer = LogFileWriter(directory: tempDirectory, isFileLoggingEnabled: { true })

        let url = await writer.currentFileURL()

        XCTAssertEqual(url.deletingLastPathComponent().standardizedFileURL, tempDirectory.standardizedFileURL)
        XCTAssertEqual(url.pathExtension, "log")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func testAllLogFileURLsOnlyIncludesDotLogFiles() async throws {
        let writer = LogFileWriter(directory: tempDirectory, isFileLoggingEnabled: { true })
        let strayFile = tempDirectory.appendingPathComponent("notes.txt")
        FileManager.default.createFile(atPath: strayFile.path, contents: Data("irrelevant".utf8))

        let logFiles = await writer.allLogFileURLs()

        XCTAssertTrue(logFiles.allSatisfy { $0.pathExtension == "log" })
        XCTAssertFalse(logFiles.contains(strayFile))
        let currentFileURL = await writer.currentFileURL()
        XCTAssertTrue(logFiles.contains(currentFileURL))
    }

    // MARK: - Pruning on init

    func testInitPrunesLogFilesOlderThanTheRetentionWindow() async throws {
        let oldFile = tempDirectory.appendingPathComponent("very-old.log")
        FileManager.default.createFile(atPath: oldFile.path, contents: Data())
        // Well past the 24h retention window, so this isn't sensitive to test-run timing jitter.
        let oldDate = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        try FileManager.default.setAttributes([.creationDate: oldDate], ofItemAtPath: oldFile.path)

        let recentFile = tempDirectory.appendingPathComponent("recent.log")
        FileManager.default.createFile(atPath: recentFile.path, contents: Data())

        let writer = LogFileWriter(directory: tempDirectory, isFileLoggingEnabled: { true })
        let remaining = await writer.allLogFileURLs()

        XCTAssertFalse(remaining.contains(oldFile), "A log file older than the retention window should be pruned on init")
        XCTAssertTrue(remaining.contains(recentFile), "A recent log file should survive pruning")
    }

    func testInitDoesNotPruneRecentlyCreatedLogFiles() async throws {
        let recentFile = tempDirectory.appendingPathComponent("just-now.log")
        FileManager.default.createFile(atPath: recentFile.path, contents: Data())

        let writer = LogFileWriter(directory: tempDirectory, isFileLoggingEnabled: { true })
        let remaining = await writer.allLogFileURLs()

        XCTAssertTrue(remaining.contains(recentFile))
    }
}
