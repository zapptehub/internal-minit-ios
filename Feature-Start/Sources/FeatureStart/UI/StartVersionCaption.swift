import Foundation

/// "Version 0.2 (9)" for the Start screen. Numbers come from the caller.
/// A missing marketing version hides the caption. A missing build number
/// drops the parentheses instead of rendering an empty pair.
enum StartVersionCaption {
    static func text(
        version: String,
        build: String,
        withBuildFormat: String,
        versionOnlyFormat: String
    ) -> String? {
        let version = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let build = build.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !version.isEmpty else { return nil }
        if build.isEmpty {
            return String(format: versionOnlyFormat, version)
        }
        return String(format: withBuildFormat, version, build)
    }

    static func marketingVersion(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func buildNumber(bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }
}
