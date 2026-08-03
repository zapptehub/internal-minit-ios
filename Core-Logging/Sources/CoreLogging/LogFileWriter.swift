import Foundation

actor LogFileWriter {
    static let shared = LogFileWriter(directory: LogFileWriter.defaultLogsDirectory)

    private let fileURL: URL
    private let retentionInterval: TimeInterval = 24 * 60 * 60
    private var fileHandle: FileHandle?
    private let isFileLoggingEnabled: @Sendable () -> Bool

    static var defaultLogsDirectory: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("logs", isDirectory: true)
    }

    /// `directory` is injectable (rather than hardcoded to `defaultLogsDirectory`) so tests can
    /// point a real `LogFileWriter` at a throwaway temp directory instead of either touching
    /// the app's actual Documents directory or only exercising this type through a mock.
    init(
        directory: URL,
        isFileLoggingEnabled: @escaping @Sendable () -> Bool = {
            LoggingConfiguration.fileLoggingEnabled
        }
    ) {
        self.isFileLoggingEnabled = isFileLoggingEnabled
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        LogFileWriter.pruneOldFiles(in: directory, retentionInterval: retentionInterval)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let sessionName = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        fileURL = directory.appendingPathComponent("\(sessionName).log")

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: fileURL)
    }

    func write(_ line: String) {
        guard isFileLoggingEnabled() else { return }
        let data = (line + "\n").data(using: .utf8) ?? Data()
        fileHandle?.write(data)
    }

    func currentFileURL() -> URL { fileURL }

    func allLogFileURLs() -> [URL] {
        let logsDir = fileURL.deletingLastPathComponent()
        let files = (try? FileManager.default.contentsOfDirectory(
            at: logsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        return files.filter { $0.pathExtension == "log" }
    }

    private static func pruneOldFiles(in directory: URL, retentionInterval: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        for file in files {
            guard let creation = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate,
                  creation < cutoff else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
