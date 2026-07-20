import Foundation

public enum LoggingConfiguration {
    private static var _fileLoggingEnabled: Bool = false

    public static var fileLoggingEnabled: Bool { _fileLoggingEnabled }

    public static func configure(fileLoggingEnabled: Bool) {
        _fileLoggingEnabled = fileLoggingEnabled
    }
}
