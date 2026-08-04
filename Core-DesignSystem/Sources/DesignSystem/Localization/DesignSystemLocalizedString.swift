import CoreExtensions
import Foundation

/// Thin wrapper around `LocalizedStringResolver` for DesignSystem's `common.*` string catalog
/// keys. Public so other feature modules can resolve shared strings (e.g. `common.tabName.*`)
/// without duplicating their own catalog/resolver. Always resolves against *this* module's
/// bundle — `Bundle.module` is SPM-generated `internal`, so it can't be exposed as a
/// caller-overridable parameter on a `public` API; it's applied inside the body instead.
public enum DesignSystemLocalizedString {
    public static func string(_ key: String, locale: Locale) -> String {
        LocalizedStringResolver.string(key, locale: locale, bundle: .module)
    }
}
