import Foundation

/// Value shown on the read-only Version row in Settings › Minit.
///
/// The title ("Version" / "Verzia" / "Verzió") lives in Settings.bundle.
/// This writes only the value, in the Start caption's number style: `0.2 (1)`.
enum SettingsVersionPreference {
    /// `PSTitleValueSpecifier` key in `Settings.bundle/Root.plist`.
    static let defaultsKey = "minit.settings.version"

    static func value(marketingVersion: String, buildNumber: String) -> String {
        let version = marketingVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = buildNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else { return "" }
        if build.isEmpty { return version }
        return "\(version) (\(build))"
    }

    static func write(
        marketingVersion: String,
        buildNumber: String,
        defaults: UserDefaults
    ) {
        defaults.set(
            value(marketingVersion: marketingVersion, buildNumber: buildNumber),
            forKey: defaultsKey
        )
    }

    static func write(bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        let marketingVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        write(marketingVersion: marketingVersion, buildNumber: buildNumber, defaults: defaults)
    }
}
