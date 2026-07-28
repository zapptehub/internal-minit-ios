import Foundation
import CoreExtensions

/// `language` step — live locale preview + durable confirmation. The
/// `selectedLanguage` vs. `confirmedLanguage` split (see `OnboardingViewModel`'s
/// doc comment on `selectedLanguage`) is what's actually subtle here; the step
/// transition itself is a one-liner via `OnboardingRouter`.
extension OnboardingViewModel {
    /// Always `true` — the language step's pre-selection counts as a real selection
    /// (decided in the Task 1.2 matrix), so Continue is enabled from first appearance.
    public var canContinueFromLanguage: Bool { true }

    public func selectLanguage(_ language: OnboardingLanguageCode) {
        guard selectedLanguage != language else { return }
        selectedLanguage = language
        analytics.trackLanguageSelected(languageCode: language.rawValue, file: #fileID)
    }

    public func continueFromLanguage() {
        confirmedLanguage = selectedLanguage
        appLanguagePreference.languageCode = selectedLanguage.rawValue
        advance(via: .languageConfirmed)
    }

    /// Pre-selects `sk`/`hu` when the device's preferred language matches, otherwise
    /// falls back to `en` — used once, from `init`, only when no device-wide
    /// `appLanguagePreference` has been recorded yet (see `initialLanguage(_:_:)`).
    static func systemPreferredLanguage(
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> OnboardingLanguageCode {
        guard let first = preferredLanguages.first else { return .en }
        switch Locale(identifier: first).language.languageCode?.identifier.lowercased() {
        case "sk": return .sk
        case "hu": return .hu
        default: return .en
        }
    }

    /// A returning device-owner's last confirmed language takes priority over a fresh
    /// guess from the device's system language — matches the product intent that a
    /// phone's owner rarely changes, so an explicit past choice should stick across
    /// logout/re-login (and even a brand-new account on the same device) until
    /// changed again or the app is reinstalled. Falls back to `systemPreferredLanguage`
    /// only when nothing has been explicitly confirmed yet.
    static func initialLanguage(
        appLanguagePreference: any AppLanguagePreferenceStoring,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> OnboardingLanguageCode {
        if let storedCode = appLanguagePreference.languageCode,
           let stored = OnboardingLanguageCode(rawValue: storedCode) {
            return stored
        }
        return systemPreferredLanguage(preferredLanguages: preferredLanguages)
    }
}
