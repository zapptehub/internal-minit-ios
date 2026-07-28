import Foundation

/// Foundation's `String(localized:bundle:locale:)` resolves *which* language's string table
/// to load using the bundle's own preferred-localization negotiation — driven by the
/// process's system language settings — and silently ignores the explicit `locale:` argument
/// for plain (non-interpolated) lookups. Confirmed empirically: passing `locale:
/// Locale(identifier: "hu")` still returns the English string whenever the simulator/device's
/// system language is English.
///
/// That defeats the entire purpose of an in-app language switcher — the whole point is
/// changing language independent of the device's own Settings. This looks the string up
/// directly from the requested language's own `.lproj` sub-bundle, bypassing that negotiation
/// entirely. Shared by every feature module that needs to resolve a string catalog key against
/// an explicit `Locale` rather than the system's preferred language.
public enum LocalizedStringResolver {
    public static func string(_ key: String, locale: Locale, bundle: Bundle) -> String {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        guard
            let path = bundle.path(forResource: languageCode, ofType: "lproj"),
            let languageBundle = Bundle(path: path)
        else {
            return bundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return languageBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
