import SwiftUI

public enum FeatureStart {
    @MainActor
    public static func createScreen(
        analytics: StartAnalyticsTracking? = nil,
        showsDemo: Bool = false,
        onGetStarted: @escaping () -> Void,
        onDemoContinue: @escaping () -> Void = {}
    ) -> some View {
        StartScreen(
            analytics: analytics,
            showsDemo: showsDemo,
            onGetStarted: onGetStarted,
            onDemoContinue: onDemoContinue
        )
    }
}
