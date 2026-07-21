import Foundation

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
        advance(via: .languageConfirmed)
    }

    /// Pre-selects `sk`/`hu` when the device's preferred language matches, otherwise
    /// falls back to `en` — used once, from `init`, before any local checkpoint exists.
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
}
