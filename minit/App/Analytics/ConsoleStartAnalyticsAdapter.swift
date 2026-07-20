import CoreLogging
import FeatureStart

final class ConsoleStartAnalyticsAdapter: StartAnalyticsTracking {
    private let logger = AppLogger(subsystem: "com.minit.app", category: "Analytics")

    func trackScreenOpened(file: String) {
        logger.info("Analytics: start_screen_opened", file: file)
    }

    func trackGetStartedTapped(file: String) {
        logger.info("Analytics: start_get_started_tapped", file: file)
    }
}
