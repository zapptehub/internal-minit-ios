public protocol AnalyticsTracking: Sendable {
    func track(event: AnalyticsEvent)
}
