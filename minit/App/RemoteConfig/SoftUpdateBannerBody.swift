import Foundation

/// Body copy for the soft-update banner.
///
/// When both the installed marketing version and the Remote Config soft-min
/// are non-blank, the banner names both. A missing or blank value keeps the
/// pre-change sentence so the banner never shows an empty version number.
enum SoftUpdateBannerBody {
    static func text(
        installedVersion: String,
        targetVersion: String?,
        versionedTemplate: String,
        fallback: String
    ) -> String {
        let installed = installedVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        let target = targetVersion?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !installed.isEmpty, !target.isEmpty else { return fallback }
        return String(format: versionedTemplate, installed, target)
    }
}
