import CoreExtensions
import Foundation

/// Thin, module-local wrapper around `LocalizedStringResolver` for DesignSystem string catalog keys.
enum DesignSystemLocalizedString {
    static func string(_ key: String, locale: Locale, bundle: Bundle = .module) -> String {
        LocalizedStringResolver.string(key, locale: locale, bundle: bundle)
    }
}
