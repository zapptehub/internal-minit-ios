import SwiftUI

public enum FeatureStart {
    @MainActor
    public static func createScreen(
        analytics: StartAnalyticsTracking? = nil,
        onGetStarted: @escaping () -> Void
    ) -> some View {
        StartScreen(analytics: analytics, onGetStarted: onGetStarted)
    }
}
