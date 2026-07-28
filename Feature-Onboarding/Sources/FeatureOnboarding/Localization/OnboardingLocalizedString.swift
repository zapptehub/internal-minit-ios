import Foundation
import CoreExtensions

/// Thin, module-local wrapper around the shared `LocalizedStringResolver` (see its doc comment
/// for why this bypasses `String(localized:bundle:locale:)`). Kept as its own type so every
/// onboarding call site reads `OnboardingLocalizedString.string(...)` without needing to know
/// about the shared implementation living in `CoreExtensions`.
enum OnboardingLocalizedString {
    static func string(_ key: String, locale: Locale, bundle: Bundle = .module) -> String {
        LocalizedStringResolver.string(key, locale: locale, bundle: bundle)
    }
}
