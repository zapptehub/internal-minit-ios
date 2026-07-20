import Foundation

actor LogFileWriter {
    static let shared = LogFileWriter()

    private let fileURL: URL
    private let retentionInterval: TimeInterval = 24 * 60 * 60
    private var fileHandle: FileHandle?

    private init() {
        let logsDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("logs", isDirectory: true)

        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)

        LogFileWriter.pruneOldFiles(in: logsDir)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let sessionName = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        fileURL = logsDir.appendingPathComponent("\(sessionName).log")

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: fileURL)
    }

    func write(_ line: String) {
        guard LoggingConfiguration.fileLoggingEnabled else { return }
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

    private static func pruneOldFiles(in directory: URL) {
        let cutoff = Date().addingTimeInterval(-(24 * 60 * 60))
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
