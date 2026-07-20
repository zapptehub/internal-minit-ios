import Foundation
import CoreLogging

protocol ErrorReporter: Sendable {
    func report(_ error: Error, context: String)
}

final class ConsoleErrorReporter: ErrorReporter {
    private let logger = AppLogger(subsystem: "com.minit.app", category: "ErrorReporter")

    func report(_ error: Error, context: String) {
        logger.error("[\(context)] \(error.localizedDescription)")
    }
}
