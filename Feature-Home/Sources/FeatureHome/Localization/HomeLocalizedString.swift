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

    /// Plural from the in-app language `.lproj`. `String(localized:locale:)` ignores
    /// `locale`, and `LocalizedStringResolver` returns the catalog's raw `%#@…@` format.
    /// The variation (`one` / `few` / `other`) is the one for `locale`, then
    /// `String(format:locale:)` fills it. `String(format:)` with no locale follows
    /// the process language.
    ///
    /// The compiled string catalog is the language `.lproj`'s `.stringsdict`. That
    /// table is parsed once per language and cached per key. A missing category
    /// uses the `other` form. A raw `%#@` token is never shown: if `other` is
    /// missing or is itself a token, the format is `%d`.
    static func quantity(_ key: String, _ value: Int, locale: Locale, bundle: Bundle = .module) -> String {
        let format = pluralFormat(key, value: value, locale: locale, bundle: bundle)
        return String(format: format, locale: locale, value)
    }

    private static func pluralFormat(_ key: String, value: Int, locale: Locale, bundle: Bundle) -> String {
        let forms = PluralTableCache.shared.forms(key, locale: locale, bundle: bundle)
        let category = pluralCategory(value, locale: locale)
        if let template = pluralTemplate(forms: forms, category: category) {
            return template
        }
        if !forms.isEmpty {
            return "%d"
        }
        let resolved = string(key, locale: locale, bundle: bundle)
        if !resolved.contains("%#@") {
            return resolved
        }
        return "%d"
    }

    /// `forms[category]` when that form is real text, otherwise the `other` form.
    /// A `%#@` token is not a usable form.
    private static func pluralTemplate(forms: [String: String], category: String) -> String? {
        if let match = forms[category], !match.contains("%#@") {
            return match
        }
        if let other = forms["other"], !other.contains("%#@") {
            return other
        }
        return nil
    }

    /// `localizedString(forKey:)` on a plural entry is the stringsdict token, which
    /// `String(format:)` does not expand for an explicit locale. Read the variation
    /// out of that same language `.lproj`.
    private static func pluralForms(in entry: NSDictionary) -> [String: String]? {
        for key in entry.allKeys {
            guard let name = key as? String, name != "NSStringLocalizedFormatKey" else { continue }
            guard let dict = entry[name] as? NSDictionary else { continue }
            if let type = dict["NSStringFormatSpecTypeKey"] as? String, type != "NSStringPluralRuleType" {
                continue
            }
            var forms: [String: String] = [:]
            for formKey in dict.allKeys {
                guard let form = formKey as? String else { continue }
                if form == "NSStringFormatSpecTypeKey" || form == "NSStringFormatValueTypeKey" { continue }
                if let text = dict[form] as? String {
                    forms[form] = text
                }
            }
            if !forms.isEmpty { return forms }
        }
        return nil
    }

    /// Integer categories for the languages this app ships: English and Hungarian
    /// are `one` / `other`, and Slovak is `one` / `few` / `other`.
    ///
    /// Slovak is the only special case. A new language needs a branch here; this
    /// does not ask the system for plural rules. Negative values are not handled:
    /// they use the same comparisons as other counts (`one` only for 1, Slovak
    /// `few` only for 2...4).
    private static func pluralCategory(_ value: Int, locale: Locale) -> String {
        switch locale.language.languageCode?.identifier {
        case "sk":
            if value == 1 { return "one" }
            if (2...4).contains(value) { return "few" }
            return "other"
        default:
            return value == 1 ? "one" : "other"
        }
    }

    /// Parsed `.stringsdict` tables. Entries are cached per (bundle, language, key)
    /// so a Home `body` pass does not list the `.lproj` or parse the plist again.
    private final class PluralTableCache: @unchecked Sendable {
        static let shared = PluralTableCache()

        private struct LanguageKey: Hashable {
            var bundlePath: String
            var language: String
        }

        private struct EntryKey: Hashable {
            var bundlePath: String
            var language: String
            var key: String
        }

        private let lock = NSLock()
        private var loadedLanguages: Set<LanguageKey> = []
        private var formsByEntry: [EntryKey: [String: String]] = [:]

        func forms(_ key: String, locale: Locale, bundle: Bundle) -> [String: String] {
            let language = locale.language.languageCode?.identifier ?? "en"
            let languageKey = LanguageKey(bundlePath: bundle.bundlePath, language: language)
            let entryKey = EntryKey(bundlePath: bundle.bundlePath, language: language, key: key)

            lock.lock()
            let alreadyLoaded = loadedLanguages.contains(languageKey)
            let cached = formsByEntry[entryKey]
            lock.unlock()
            if alreadyLoaded {
                return cached ?? [:]
            }

            let table = loadTable(language: language, bundle: bundle)

            lock.lock()
            if !loadedLanguages.contains(languageKey) {
                for (tableKey, entryForms) in table {
                    let stored = EntryKey(bundlePath: bundle.bundlePath, language: language, key: tableKey)
                    formsByEntry[stored] = entryForms
                }
                loadedLanguages.insert(languageKey)
            }
            let resolved = formsByEntry[entryKey] ?? [:]
            lock.unlock()
            return resolved
        }

        private func loadTable(language: String, bundle: Bundle) -> [String: [String: String]] {
            guard let path = bundle.path(forResource: language, ofType: "lproj") else { return [:] }
            let lproj = URL(fileURLWithPath: path, isDirectory: true)
            let dictionaries = (try? FileManager.default.contentsOfDirectory(
                at: lproj,
                includingPropertiesForKeys: nil
            ))?.filter { $0.pathExtension == "stringsdict" } ?? []
            var table: [String: [String: String]] = [:]
            for url in dictionaries {
                guard let root = NSDictionary(contentsOf: url) else { continue }
                for case let key as String in root.allKeys {
                    guard let entry = root[key] as? NSDictionary,
                          let forms = HomeLocalizedString.pluralForms(in: entry) else { continue }
                    table[key] = forms
                }
            }
            return table
        }
    }
}
