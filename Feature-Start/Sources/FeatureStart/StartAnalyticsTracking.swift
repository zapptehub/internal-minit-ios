/// Every method takes a `file` parameter — callers pass `#fileID` explicitly (see call sites
/// in `StartScreen`) so conforming loggers (e.g. `ConsoleStartAnalyticsAdapter`) can report
/// where the event was actually triggered, rather than their own adapter file.
public protocol StartAnalyticsTracking: Sendable {
    func trackScreenOpened(file: String)
    func trackGetStartedTapped(file: String)
}
