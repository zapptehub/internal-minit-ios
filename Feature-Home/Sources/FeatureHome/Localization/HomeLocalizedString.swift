import CoreExtensions
import Foundation

/// Thin, module-local wrapper around the shared `LocalizedStringResolver` (see its doc comment
/// for why this bypasses `String(localized:bundle:locale:)`). Kept as its own type so every
/// Home call site reads `HomeLocalizedString.string(...)` without needing to know about the
/// shared implementation living in `CoreExtensions`.
enum HomeLocalizedString {
    static func string(_ key: String, locale: Locale, bundle: Bundle = .module) -> String {
        LocalizedStringResolver.string(key, locale: locale, bundle: bundle)
    }
}
