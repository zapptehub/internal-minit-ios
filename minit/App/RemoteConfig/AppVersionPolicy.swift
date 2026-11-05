import Foundation

/// Remote Config parameter names. Every channel reads the same marketing-version keys.
enum RemoteConfigKey {
    static let maintenanceBlocking = "maintenance_blocking"
    static let maintenanceBlockingMessage = "maintenance_blocking_message"
    static let maintenanceBannerMessage = "maintenance_banner_message"
    static let maintenanceBannerStart = "maintenance_banner_start"
    static let maintenanceBannerEnd = "maintenance_banner_end"
    static let minVersionIOS = "min_version_ios"
    static let minVersionAndroid = "min_version_android"
    static let softMinVersionIOS = "soft_min_version_ios"
    static let softMinVersionAndroid = "soft_min_version_android"
    static let updateURLIOS = "update_url_ios"
    static let updateURLAndroid = "update_url_android"

    static let all = [
        maintenanceBlocking,
        maintenanceBlockingMessage,
        maintenanceBannerMessage,
        maintenanceBannerStart,
        maintenanceBannerEnd,
        minVersionIOS,
        minVersionAndroid,
        softMinVersionIOS,
        softMinVersionAndroid,
        updateURLIOS,
        updateURLAndroid,
    ]
}

/// In-app defaults. A missing or failed fetch leaves every gate off.
enum RemoteConfigDefaults {
    static let maintenanceBlocking = false
    static let strings: [String: String] = [
        RemoteConfigKey.maintenanceBlockingMessage: "{}",
        RemoteConfigKey.maintenanceBannerMessage: "{}",
        RemoteConfigKey.maintenanceBannerStart: "",
        RemoteConfigKey.maintenanceBannerEnd: "",
        RemoteConfigKey.minVersionIOS: "",
        RemoteConfigKey.minVersionAndroid: "",
        RemoteConfigKey.softMinVersionIOS: "",
        RemoteConfigKey.softMinVersionAndroid: "",
        RemoteConfigKey.updateURLIOS: "",
        RemoteConfigKey.updateURLAndroid: "",
    ]

    static var firebaseValues: [String: NSObject] {
        var values: [String: NSObject] = [
            RemoteConfigKey.maintenanceBlocking: NSNumber(value: maintenanceBlocking),
        ]
        for (key, value) in strings {
            values[key] = value as NSString
        }
        return values
    }
}

/// Same interval on development, internal, and release. Firebase may still throttle.
enum RemoteConfigFetchPolicy {
    static let minimumFetchInterval: TimeInterval = 0
}

enum AppDistributionChannel: String, Equatable, CaseIterable {
    case development
    case `internal`
    case release

    var usesTesterCopy: Bool {
        switch self {
        case .development, .internal:
            return true
        case .release:
            return false
        }
    }

    /// Known Sentry environment strings map to themselves. Anything else uses `fallback`.
    static func resolve(environment: String?, fallback: AppDistributionChannel) -> AppDistributionChannel {
        guard let environment, !environment.isEmpty, !environment.hasPrefix("$("),
              let channel = AppDistributionChannel(rawValue: environment) else {
            return fallback
        }
        return channel
    }
}

/// Marketing version only (`CFBundleShortVersionString`). Build number is not a gate input.
enum InstalledAppVersion {
    static func marketingVersion(infoDictionary: [String: Any]) -> String {
        infoDictionary["CFBundleShortVersionString"] as? String ?? ""
    }

    static func marketingVersion(bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

/// Dotted marketing versions. A missing component is 0, so `1.0` equals `1.0.0`.
/// A blank string or a non-numeric component is invalid.
enum MarketingVersion {
    static func components(_ raw: String) -> [Int]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: false)
        guard !parts.isEmpty else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy(isASCIIDigit), let value = Int(part) else {
                return nil
            }
            numbers.append(value)
        }
        return numbers
    }

    static func compare(_ lhs: [Int], _ rhs: [Int]) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        for index in 0..<count {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
        }
        return .orderedSame
    }

    /// False when `floor` is blank or invalid, which turns that comparator off.
    static func isStrictlyAbove(floor: String, installed: [Int]) -> Bool {
        guard let floorComponents = components(floor) else { return false }
        return compare(floorComponents, installed) == .orderedDescending
    }

    private nonisolated static func isASCIIDigit(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            scalar.value >= 48 && scalar.value <= 57
        }
    }
}

struct RemoteConfigSnapshot: Equatable {
    var maintenanceBlocking: Bool
    var maintenanceBlockingMessage: String
    var maintenanceBannerMessage: String
    var maintenanceBannerStart: String
    var maintenanceBannerEnd: String
    var minVersionIOS: String
    var softMinVersionIOS: String
    var updateURLIOS: String

    static let defaults = RemoteConfigSnapshot(
        maintenanceBlocking: RemoteConfigDefaults.maintenanceBlocking,
        maintenanceBlockingMessage: RemoteConfigDefaults.strings[RemoteConfigKey.maintenanceBlockingMessage] ?? "{}",
        maintenanceBannerMessage: RemoteConfigDefaults.strings[RemoteConfigKey.maintenanceBannerMessage] ?? "{}",
        maintenanceBannerStart: RemoteConfigDefaults.strings[RemoteConfigKey.maintenanceBannerStart] ?? "",
        maintenanceBannerEnd: RemoteConfigDefaults.strings[RemoteConfigKey.maintenanceBannerEnd] ?? "",
        minVersionIOS: RemoteConfigDefaults.strings[RemoteConfigKey.minVersionIOS] ?? "",
        softMinVersionIOS: RemoteConfigDefaults.strings[RemoteConfigKey.softMinVersionIOS] ?? "",
        updateURLIOS: RemoteConfigDefaults.strings[RemoteConfigKey.updateURLIOS] ?? ""
    )
}

extension RemoteConfigSnapshot {
    /// Reads the iOS marketing keys only. Android floors and any build-number keys are ignored.
    init(values: [String: String], maintenanceBlocking: Bool = false) {
        self.init(
            maintenanceBlocking: maintenanceBlocking,
            maintenanceBlockingMessage: values[RemoteConfigKey.maintenanceBlockingMessage] ?? "{}",
            maintenanceBannerMessage: values[RemoteConfigKey.maintenanceBannerMessage] ?? "{}",
            maintenanceBannerStart: values[RemoteConfigKey.maintenanceBannerStart] ?? "",
            maintenanceBannerEnd: values[RemoteConfigKey.maintenanceBannerEnd] ?? "",
            minVersionIOS: values[RemoteConfigKey.minVersionIOS] ?? "",
            softMinVersionIOS: values[RemoteConfigKey.softMinVersionIOS] ?? "",
            updateURLIOS: values[RemoteConfigKey.updateURLIOS] ?? ""
        )
    }
}

/// One logout per blocking-maintenance episode.
///
/// Before any snapshot, the previous value is not blocking, so a cold start whose
/// first snapshot is already blocking is a rising edge. Further observations that
/// stay blocking do not request again. Force update, soft update, and the downtime
/// banner pass `isBlocking: false`. When blocking ends, the next rise can request
/// again; nothing here restores the session that was cleared.
struct BlockingMaintenanceLogoutEdge: Equatable {
    private var hasObserved = false
    private var wasBlocking = false

    mutating func observe(isBlocking: Bool) -> Bool {
        let previouslyBlocking = hasObserved && wasBlocking
        hasObserved = true
        wasBlocking = isBlocking
        return Self.shouldRequestLogout(wasBlocking: previouslyBlocking, isBlocking: isBlocking)
    }

    static func shouldRequestLogout(wasBlocking: Bool, isBlocking: Bool) -> Bool {
        isBlocking && !wasBlocking
    }
}

/// Pure maintenance and minimum-version decision. No Firebase types.
/// The soft banner's close control stores `dismissedSoftVersionDefaultsKey` and stays
/// quiet until the soft floor changes. There is no soft-update dialog.
/// The banner's Update button uses the same `UpdateAction` as the force-update button.
enum AppVersionPolicy {
    /// The soft banner close control stores this UserDefaults value and stays quiet until the soft floor changes.
    static let dismissedSoftVersionDefaultsKey = "minit.remoteConfig.dismissedSoftMinVersionIOS"

    struct Input: Equatable {
        var snapshot: RemoteConfigSnapshot
        var channel: AppDistributionChannel
        var installedMarketingVersion: String
        var languageCode: String
        var now: Date
        var dismissedSoftThreshold: String?
        var dismissedBannerIdentity: String?
    }

    struct Decision: Equatable {
        var blocking: Blocking?
        var force: Force?
        var softBanner: SoftBanner?
        var downtimeBanner: DowntimeBanner?

        /// Blocking and force are non-dismissable sheets. Banners leave the app usable.
        var coversApp: Bool {
            blocking != nil || force != nil
        }

        static let clear = Decision(
            blocking: nil,
            force: nil,
            softBanner: nil,
            downtimeBanner: nil
        )
    }

    struct Blocking: Equatable {
        var body: ResolvedText
    }

    enum ResolvedText: Equatable {
        case remote(String)
        case catalogFallback
    }

    struct Force: Equatable {
        var usesTesterCopy: Bool
        /// Always set. Release without a usable URL is `UpdateAction.unavailable`.
        var action: UpdateAction
    }

    enum UpdateAction: Equatable {
        /// Release, and `update_url_ios` is a non-empty https or `itms-apps` URL.
        case openStore(URL)
        /// Development and internal. Update opens the tester alert instead of a URL.
        case testerAlert
        /// Release with an empty or disallowed URL. The Update button stays hidden.
        case unavailable
    }

    struct SoftBanner: Equatable {
        var usesTesterCopy: Bool
        /// Trimmed soft floor. Close writes this exact string.
        var threshold: String
        /// Same rules as force update. `.unavailable` hides the Update button.
        var action: UpdateAction
    }

    struct DowntimeBanner: Equatable {
        var message: String
        var identity: String
    }

    static func evaluate(_ input: Input) -> Decision {
        if input.snapshot.maintenanceBlocking {
            let body = resolveMessage(
                json: input.snapshot.maintenanceBlockingMessage,
                languageCode: input.languageCode
            )
            return Decision(
                blocking: Blocking(body: body.map(ResolvedText.remote) ?? .catalogFallback),
                force: nil,
                softBanner: nil,
                downtimeBanner: nil
            )
        }

        if let force = resolveForce(input) {
            return Decision(blocking: nil, force: force, softBanner: nil, downtimeBanner: nil)
        }
        return Decision(
            blocking: nil,
            force: nil,
            softBanner: resolveSoftBanner(input),
            downtimeBanner: resolveDowntimeBanner(input)
        )
    }

    /// What a maintenance Reload does after fetch + activate.
    /// A successful fetch keeps the activated snapshot. A failed fetch keeps the cached
    /// snapshot and ignores the activated payload. The gate passes the live snapshot as
    /// `cached`, so a failure cannot restore values from when Reload was tapped.
    /// The blocking sheet stays only when that snapshot still has maintenance on;
    /// otherwise the normal gate runs.
    enum MaintenanceReloadOutcome: Equatable {
        case cleared
        case stillUnavailable
    }

    struct MaintenanceReloadResolution: Equatable {
        var outcome: MaintenanceReloadOutcome
        var snapshot: RemoteConfigSnapshot
    }

    static func resolveMaintenanceReload(
        fetchSucceeded: Bool,
        activated: RemoteConfigSnapshot,
        cached: RemoteConfigSnapshot
    ) -> MaintenanceReloadResolution {
        let snapshot = fetchSucceeded ? activated : cached
        let outcome: MaintenanceReloadOutcome = snapshot.maintenanceBlocking ? .stillUnavailable : .cleared
        return MaintenanceReloadResolution(outcome: outcome, snapshot: snapshot)
    }

    static func resolveMessage(json: String, languageCode: String) -> String? {
        let trimmed = json.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var tried = Set<String>()
        for code in languageCandidates(languageCode) + ["en"] {
            guard tried.insert(code).inserted else { continue }
            if let text = nonEmptyString(object[code]) {
                return text
            }
        }
        return nil
    }

    static func bannerIdentity(message: String, start: String, end: String) -> String {
        [message, start, end].joined(separator: "\u{1e}")
    }

    static func parseTimestamp(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: trimmed) { return date }
        let internet = ISO8601DateFormatter()
        internet.formatOptions = [.withInternetDateTime]
        return internet.date(from: trimmed)
    }

    private static func resolveForce(_ input: Input) -> Force? {
        guard let installed = MarketingVersion.components(input.installedMarketingVersion) else {
            return nil
        }
        guard MarketingVersion.isStrictlyAbove(floor: input.snapshot.minVersionIOS, installed: installed) else {
            return nil
        }
        return Force(usesTesterCopy: input.channel.usesTesterCopy, action: updateAction(input))
    }

    /// Release opens a store URL when one is set. Development and internal open the tester alert.
    private static func updateAction(_ input: Input) -> UpdateAction {
        if input.channel.usesTesterCopy {
            return .testerAlert
        }
        guard let url = releaseUpdateURL(channel: input.channel, raw: input.snapshot.updateURLIOS) else {
            return .unavailable
        }
        return .openStore(url)
    }

    private static func resolveSoftBanner(_ input: Input) -> SoftBanner? {
        guard let installed = MarketingVersion.components(input.installedMarketingVersion) else {
            return nil
        }
        let softFloor = input.snapshot.softMinVersionIOS.trimmingCharacters(in: .whitespacesAndNewlines)
        guard MarketingVersion.isStrictlyAbove(floor: softFloor, installed: installed) else {
            return nil
        }
        let dismissed = input.dismissedSoftThreshold?.trimmingCharacters(in: .whitespacesAndNewlines)
        if dismissed == softFloor {
            return nil
        }
        return SoftBanner(
            usesTesterCopy: input.channel.usesTesterCopy,
            threshold: softFloor,
            action: updateAction(input)
        )
    }

    private static let allowedUpdateURLSchemes: Set<String> = ["https", "itms-apps"]

    /// Release only. Anything other than `https` or `itms-apps` is treated as no URL.
    private static func releaseUpdateURL(channel: AppDistributionChannel, raw: String) -> URL? {
        guard channel == .release else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              allowedUpdateURLSchemes.contains(scheme) else {
            return nil
        }
        return url
    }

    private static func resolveDowntimeBanner(_ input: Input) -> DowntimeBanner? {
        let rawMessage = input.snapshot.maintenanceBannerMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let message = resolveMessage(
            json: rawMessage,
            languageCode: input.languageCode
        ) else {
            return nil
        }
        let start = input.snapshot.maintenanceBannerStart.trimmingCharacters(in: .whitespacesAndNewlines)
        let end = input.snapshot.maintenanceBannerEnd.trimmingCharacters(in: .whitespacesAndNewlines)
        guard windowAllows(start: start, end: end, now: input.now) else { return nil }
        let identity = bannerIdentity(message: rawMessage, start: start, end: end)
        if input.dismissedBannerIdentity == identity { return nil }
        return DowntimeBanner(message: message, identity: identity)
    }

    private static func windowAllows(start: String, end: String, now: Date) -> Bool {
        if start.isEmpty && end.isEmpty { return true }
        guard let startDate = parseTimestamp(start), let endDate = parseTimestamp(end) else {
            return false
        }
        return startDate <= now && now < endDate
    }

    private static func languageCandidates(_ languageCode: String) -> [String] {
        let lowered = languageCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return [] }
        let primary = String(lowered.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? Substring(lowered))
        if primary.isEmpty || primary == lowered { return [lowered] }
        return [lowered, primary]
    }

    private static func nonEmptyString(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Tester mail targets. Subject and body come from the catalog; this only builds the URL.
enum RemoteConfigTesterMail {
    static let email = "armands.berzins@saleseverest.com"

    static func addressURL() -> URL? {
        URL(string: "mailto:\(email)")
    }

    static func requestBody(template: String, installedVersion: String) -> String {
        String(format: template, installedVersion)
    }

    /// `mailto:` with a prefilled subject and body.
    /// Query values are percent-encoded, including `&`, `+`, and `=`, which `URLQueryItem` leaves raw.
    static func requestInviteURL(subject: String, body: String) -> URL? {
        let query = "subject=\(percentEncodeQueryValue(subject))&body=\(percentEncodeQueryValue(body))"
        return URL(string: "mailto:\(email)?\(query)")
    }

    /// `urlQueryAllowed` still contains `&`, `+`, and `=`. Those split or rewrite a query value.
    private static func percentEncodeQueryValue(_ value: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}

enum RemoteConfigLanguage {
    static func code(from locale: Locale) -> String {
        locale.language.languageCode?.identifier.lowercased() ?? "en"
    }
}
