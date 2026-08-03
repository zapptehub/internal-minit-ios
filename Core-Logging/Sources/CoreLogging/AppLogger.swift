import Foundation
import os

/// Abstracts `LogFileWriter.write(_:)` so `AppLogger`'s level-dispatch and message formatting
/// can be verified against a fake in tests, without touching the real singleton or filesystem.
protocol LogFileWriting: Sendable {
    func write(_ line: String) async
}

extension LogFileWriter: LogFileWriting {}

public struct AppLogger: Sendable {
    private let subsystem: String
    private let category: String
    private let osLogger: Logger
    private let writer: LogFileWriting
    private let isFileLoggingEnabled: @Sendable () -> Bool

    public init(subsystem: String, category: String) {
        self.init(
            subsystem: subsystem,
            category: category,
            writer: LogFileWriter.shared,
            isFileLoggingEnabled: { LoggingConfiguration.fileLoggingEnabled }
        )
    }

    init(
        subsystem: String,
        category: String,
        writer: LogFileWriting,
        isFileLoggingEnabled: @escaping @Sendable () -> Bool = {
            LoggingConfiguration.fileLoggingEnabled
        }
    ) {
        self.subsystem = subsystem
        self.category = category
        self.osLogger = Logger(subsystem: subsystem, category: category)
        self.writer = writer
        self.isFileLoggingEnabled = isFileLoggingEnabled
    }

    public func debug(_ message: String, file: String = #fileID) {
        osLogger.debug("\(consoleMessage(message, file: file), privacy: .public)")
        writeToFile(level: "DEBUG", message: message)
    }

    public func info(_ message: String, file: String = #fileID) {
        osLogger.info("\(consoleMessage(message, file: file), privacy: .public)")
        writeToFile(level: "INFO", message: message)
    }

    public func warning(_ message: String, file: String = #fileID) {
        osLogger.warning("\(consoleMessage(message, file: file), privacy: .public)")
        writeToFile(level: "WARNING", message: message)
    }

    public func error(_ message: String, file: String = #fileID) {
        osLogger.error("\(consoleMessage(message, file: file), privacy: .public)")
        writeToFile(level: "ERROR", message: message)
    }

    /// Formats as `[CLOG] [<iso8601>] [<file>] <message>`. The `[CLOG]` tag lets you filter
    /// these out from system/UIKit console noise; `file` defaults to the caller's source file
    /// via `#fileID`, though most call sites forward their own `#fileID` explicitly (e.g.
    /// through `LoginAnalyticsTracking`) so this reports the true origin, not just whichever
    /// adapter happens to call into `AppLogger`.
    private func consoleMessage(_ message: String, file: String) -> String {
        let timestamp = AppLogger.timestampFormatter.string(from: Date())
        let fileName = file.split(separator: "/").last.map(String.init) ?? file
        return "[CLOG] [\(timestamp)] [\(fileName)] \(message)"
    }

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withFractionalSeconds]
        return formatter
    }()

    private func writeToFile(level: String, message: String) {
        guard isFileLoggingEnabled() else { return }
        let timestamp = AppLogger.timestampFormatter.string(from: Date())
        let line = "\(timestamp) [\(level)] \(subsystem)/\(category) — \(message)"
        Task {
            await writer.write(line)
        }
    }
}
