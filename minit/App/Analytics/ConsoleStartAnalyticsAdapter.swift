import CoreLogging
import FeatureStart

final class ConsoleStartAnalyticsAdapter: StartAnalyticsTracking {
    private let logger = AppLogger(subsystem: "com.minit.app", category: "Analytics")

    private func report(_ message: String, file: String) {
        logger.info(message, file: file)
        AppLogger.forward(message)
    }

    func trackScreenOpened(file: String) {
        report("Analytics: start_screen_opened", file: file)
    }

    func trackGetStartedTapped(file: String) {
        report("Analytics: start_get_started_tapped", file: file)
    }
}
