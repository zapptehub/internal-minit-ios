import Foundation

public enum LogExporter {
    public static func allLogFiles() async -> [URL] {
        await LogFileWriter.shared.allLogFileURLs()
    }
}
