import CoreExtensions
import Foundation

/// App-target string catalog lookup. Uses `LocalizedStringResolver` so an in-app
/// language choice wins over the device language. See `LocalizedStringResolver`.
enum AppLocalizedString {
    static func string(_ key: String, locale: Locale, bundle: Bundle = .main) -> String {
        LocalizedStringResolver.string(key, locale: locale, bundle: bundle)
    }
}

/// Title and message for a launch failure. Session restore and onboarding status
/// each resolve their own catalog strings against `locale` (the in-app override
/// `ContentView` publishes, otherwise the system language).
struct LaunchFailureCopy: Equatable {
    let title: String
    let message: String
    let retry: String

    init?(state: AppFlowViewModel.State, locale: Locale, bundle: Bundle = .main) {
        let titleKey: String
        let messageKey: String
        switch state {
        case .sessionRestoreFailed:
            titleKey = "appFlow.sessionRestoreFailed.title"
            messageKey = "appFlow.sessionRestoreFailed.message"
        case .onboardingStatusFailed:
            titleKey = "appFlow.onboardingStatusFailed.title"
            messageKey = "appFlow.onboardingStatusFailed.message"
        case .loading, .unauthenticated, .onboarding, .authenticated:
            return nil
        }
        title = AppLocalizedString.string(titleKey, locale: locale, bundle: bundle)
        message = AppLocalizedString.string(messageKey, locale: locale, bundle: bundle)
        retry = AppLocalizedString.string("appFlow.retry", locale: locale, bundle: bundle)
    }
}
