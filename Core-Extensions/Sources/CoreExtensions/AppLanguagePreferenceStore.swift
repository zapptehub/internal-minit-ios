import Foundation

/// Device-wide (not account-scoped) language preference. Unlike onboarding's own
/// resume checkpoint — which is keyed per `userId` and cleared once onboarding
/// completes — this survives login/logout and app relaunches, and is only cleared by
/// an app reinstall. Matches the product intent that a phone's owner rarely changes,
/// so an explicit in-app language choice should stick regardless of which account is
/// currently signed in.
@MainActor
public protocol AppLanguagePreferenceStoring: AnyObject {
    /// The last language code explicitly confirmed in-app (e.g. `"en"`, `"hu"`,
    /// `"sk"`), or `nil` if no explicit choice has ever been made — callers should
    /// fall back to their own default-detection logic (e.g. the device's system
    /// language) in that case.
    var languageCode: String? { get set }
}

@MainActor
public final class UserDefaultsAppLanguagePreferenceStore: AppLanguagePreferenceStoring {
    /// Shared with any `@AppStorage` reader (e.g. the app's root view) that needs to
    /// react live to changes written through this store, without a direct dependency
    /// between the two.
    public static let defaultKey = "minit.app.language"

    private let userDefaults: UserDefaults
    private let key: String

    public init(userDefaults: UserDefaults = .standard, key: String = UserDefaultsAppLanguagePreferenceStore.defaultKey) {
        self.userDefaults = userDefaults
        self.key = key
    }

    public var languageCode: String? {
        get { userDefaults.string(forKey: key) }
        set { userDefaults.set(newValue, forKey: key) }
    }
}
