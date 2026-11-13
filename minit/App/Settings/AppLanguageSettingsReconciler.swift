import Foundation
import CoreExtensions

/// Snapshot of the language keys in one UserDefaults domain.
struct AppLanguageSettingsSnapshot: Equatable {
    var storedLanguageCode: String?
    /// Last per-app language this app recorded. Nil if it has never recorded one.
    var appliedLanguageCode: String?
    /// App-domain `AppleLanguages`. Nil when that key is absent (not an empty list).
    var appleLanguageCodes: [String]?
    var followSystemLanguage: Bool
}

/// What to write back so Settings › Minit › Preferred Language and the in-app
/// store describe the same language.
struct AppLanguageSettingsDecision: Equatable {
    var storedLanguageCode: String?
    var appliedLanguageCode: String?
    /// Non-nil replaces `AppleLanguages` (an empty array removes the key).
    /// Nil leaves the key untouched.
    var appleLanguagesWrite: [String]?
    var followSystemLanguage: Bool
    /// Nil means the UI follows the autoupdating system locale.
    var displayLanguageCode: String?
}

/// Decides which language the UI shows.
///
/// An explicit per-app language in the app's own defaults (`AppleLanguages`,
/// written by Settings › Minit › Preferred Language) wins over the onboarding
/// store. A store value with no per-app language is published once so Settings
/// shows the same choice. Clearing the per-app language follows the device.
enum AppLanguageSettingsLogic {
    static let supported: Set<String> = ["en", "sk", "hu"]

    static func languageCode(from identifier: String?) -> String? {
        guard let identifier else { return nil }
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: "_", with: "-")
        let code = Locale(identifier: normalized).language.languageCode?.identifier.lowercased() ?? ""
        return supported.contains(code) ? code : nil
    }

    static func decide(_ snapshot: AppLanguageSettingsSnapshot) -> AppLanguageSettingsDecision {
        let perApp = languageCode(from: snapshot.appleLanguageCodes?.first)
        let stored = languageCode(from: snapshot.storedLanguageCode)
        let applied = languageCode(from: snapshot.appliedLanguageCode)
        let hasAppleKey = snapshot.appleLanguageCodes != nil

        if hasAppleKey, let perApp, perApp != applied {
            return AppLanguageSettingsDecision(
                storedLanguageCode: perApp,
                appliedLanguageCode: perApp,
                appleLanguagesWrite: nil,
                followSystemLanguage: false,
                displayLanguageCode: perApp
            )
        }

        if !hasAppleKey, applied != nil {
            return AppLanguageSettingsDecision(
                storedLanguageCode: nil,
                appliedLanguageCode: nil,
                appleLanguagesWrite: nil,
                followSystemLanguage: true,
                displayLanguageCode: nil
            )
        }

        if let stored {
            return AppLanguageSettingsDecision(
                storedLanguageCode: stored,
                appliedLanguageCode: stored,
                appleLanguagesWrite: perApp != stored ? [stored] : nil,
                followSystemLanguage: false,
                displayLanguageCode: stored
            )
        }

        if hasAppleKey, let perApp {
            return AppLanguageSettingsDecision(
                storedLanguageCode: perApp,
                appliedLanguageCode: perApp,
                appleLanguagesWrite: nil,
                followSystemLanguage: false,
                displayLanguageCode: perApp
            )
        }

        return AppLanguageSettingsDecision(
            storedLanguageCode: nil,
            appliedLanguageCode: nil,
            appleLanguagesWrite: nil,
            followSystemLanguage: snapshot.followSystemLanguage,
            displayLanguageCode: nil
        )
    }
}

/// Reads and writes the language keys for Settings and the in-app store.
enum AppLanguageSettingsReconciler {
    static let appliedKey = "minit.settings.appliedPerAppLanguage"
    static let followSystemKey = "minit.settings.followSystemLanguage"
    static let appleLanguagesKey = "AppleLanguages"

    static func reconcile(
        defaults: UserDefaults = .standard,
        domainName: String = Bundle.main.bundleIdentifier ?? ""
    ) {
        let current = snapshot(defaults: defaults, domainName: domainName)
        apply(AppLanguageSettingsLogic.decide(current), snapshot: current, defaults: defaults)
    }

    static func snapshot(defaults: UserDefaults, domainName: String) -> AppLanguageSettingsSnapshot {
        let domain = defaults.persistentDomain(forName: domainName) ?? [:]
        let appleCodes: [String]?
        if domain.keys.contains(appleLanguagesKey) {
            appleCodes = domain[appleLanguagesKey] as? [String] ?? []
        } else {
            appleCodes = nil
        }
        return AppLanguageSettingsSnapshot(
            storedLanguageCode: domain[UserDefaultsAppLanguagePreferenceStore.defaultKey] as? String,
            appliedLanguageCode: domain[appliedKey] as? String,
            appleLanguageCodes: appleCodes,
            followSystemLanguage: domain[followSystemKey] as? Bool ?? false
        )
    }

    static func apply(
        _ decision: AppLanguageSettingsDecision,
        snapshot: AppLanguageSettingsSnapshot,
        defaults: UserDefaults
    ) {
        let storedKey = UserDefaultsAppLanguagePreferenceStore.defaultKey
        let storedNow = AppLanguageSettingsLogic.languageCode(from: snapshot.storedLanguageCode)
        if decision.storedLanguageCode != storedNow
            || (decision.storedLanguageCode == nil && snapshot.storedLanguageCode != nil) {
            if let code = decision.storedLanguageCode {
                defaults.set(code, forKey: storedKey)
            } else {
                defaults.removeObject(forKey: storedKey)
            }
        }

        let appliedNow = AppLanguageSettingsLogic.languageCode(from: snapshot.appliedLanguageCode)
        if decision.appliedLanguageCode != appliedNow
            || (decision.appliedLanguageCode == nil && snapshot.appliedLanguageCode != nil) {
            if let code = decision.appliedLanguageCode {
                defaults.set(code, forKey: appliedKey)
            } else {
                defaults.removeObject(forKey: appliedKey)
            }
        }

        if let apple = decision.appleLanguagesWrite {
            if apple.isEmpty {
                defaults.removeObject(forKey: appleLanguagesKey)
            } else {
                defaults.set(apple, forKey: appleLanguagesKey)
            }
        }

        if snapshot.followSystemLanguage != decision.followSystemLanguage {
            defaults.set(decision.followSystemLanguage, forKey: followSystemKey)
        }
    }
}
