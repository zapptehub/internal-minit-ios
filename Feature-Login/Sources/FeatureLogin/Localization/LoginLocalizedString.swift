import Foundation
import CoreExtensions

/// Thin, module-local wrapper around the shared `LocalizedStringResolver` (see its doc comment
/// for why this bypasses `String(localized:bundle:locale:)`). Mirrors `FeatureOnboarding`'s
/// `OnboardingLocalizedString`.
enum LoginLocalizedString {
    static func string(_ key: String, locale: Locale, bundle: Bundle = .module) -> String {
        LocalizedStringResolver.string(key, locale: locale, bundle: bundle)
    }
}
