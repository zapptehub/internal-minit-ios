import XCTest
@testable import minit

final class AppVersionPolicyTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-11-05T12:00:00Z")!

    func testDottedMarketingVersionsTreatMissingPartsAsZero() {
        XCTAssertEqual(MarketingVersion.components("1.0"), [1, 0])
        XCTAssertEqual(MarketingVersion.components("1.0.0"), [1, 0, 0])
        XCTAssertEqual(MarketingVersion.components("1"), [1])
        XCTAssertEqual(
            MarketingVersion.compare(MarketingVersion.components("1.0")!, MarketingVersion.components("1.0.0")!),
            .orderedSame
        )
        XCTAssertEqual(
            MarketingVersion.compare(MarketingVersion.components("1")!, MarketingVersion.components("1.0.0")!),
            .orderedSame
        )
        XCTAssertEqual(
            MarketingVersion.compare(MarketingVersion.components("1.2")!, MarketingVersion.components("1.10")!),
            .orderedAscending
        )

        XCTAssertNil(evaluate(minVersion: "1.0.0", installed: "1.0").force)
        XCTAssertNil(evaluate(minVersion: "1.0", installed: "1.0.0").force)
        XCTAssertNil(evaluate(softVersion: "1.0.0", installed: "1.0").softBanner)
        XCTAssertNil(evaluate(minVersion: "1", installed: "1.0.0").force)

        XCTAssertNotNil(evaluate(minVersion: "1.0.1", installed: "1.0").force, "1.0.1 is above 1.0")
        XCTAssertNotNil(evaluate(softVersion: "1.0.1", installed: "1.0").softBanner, "soft 1.0.1 is above 1.0")
        XCTAssertNotNil(evaluate(minVersion: "1.10", installed: "1.2").force, "1.10 is above 1.2")
        XCTAssertNil(evaluate(minVersion: "1.2", installed: "1.10").force)
    }

    func testInvalidInstalledVersionSkipsUpdateGate() {
        for installed in ["", "   ", "1.0-beta", "v1.2", "1..2", "1.a", ".1"] {
            let decision = evaluate(
                blockingMessage: #"{"en":"Closed"}"#,
                bannerMessage: #"{"en":"Tonight"}"#,
                minVersion: "0.1",
                softVersion: "0.1",
                installed: installed,
                blocking: false
            )
            XCTAssertNil(decision.force, installed)
            XCTAssertNil(decision.softBanner, installed)
            XCTAssertNil(decision.blocking, installed)
            XCTAssertEqual(decision.downtimeBanner?.message, "Tonight", installed)
        }

        let blocking = evaluate(
            blockingMessage: #"{"en":"Closed"}"#,
            minVersion: "9.0",
            softVersion: "9.0",
            installed: "not-a-version",
            blocking: true
        )
        XCTAssertEqual(blocking.blocking?.body, .remote("Closed"))
        XCTAssertNil(blocking.force)
        XCTAssertNil(blocking.softBanner)
    }

    func testBlankOrInvalidFloorTurnsThatComparatorOff() {
        let soft = evaluate(minVersion: "", softVersion: "2.0", installed: "1.0")
        XCTAssertEqual(soft.softBanner?.threshold, "2.0", "blank hard floor leaves soft on")
        XCTAssertNil(soft.force)

        XCTAssertNotNil(
            evaluate(minVersion: "nope", softVersion: "2.0", installed: "1.0").softBanner,
            "invalid hard floor leaves soft on"
        )
        XCTAssertNotNil(evaluate(minVersion: "2.0", softVersion: "", installed: "1.0").force, "blank soft floor leaves force on")
        XCTAssertNil(evaluate(minVersion: "2.0", softVersion: "", installed: "1.0").softBanner)
        XCTAssertNotNil(
            evaluate(minVersion: "2.0", softVersion: "soon", installed: "1.0").force,
            "invalid soft floor leaves force on"
        )
        XCTAssertNil(evaluate(minVersion: "", softVersion: "", installed: "1.0").force)
        XCTAssertNil(evaluate(minVersion: "", softVersion: "", installed: "1.0").softBanner)
        XCTAssertNil(evaluate(minVersion: " ", softVersion: "x", installed: "1.0").force)
        XCTAssertNil(evaluate(minVersion: " ", softVersion: "x", installed: "1.0").softBanner)
        XCTAssertNil(evaluate(minVersion: "1.0", softVersion: "1.0.0", installed: "1.0").force)
        XCTAssertNil(evaluate(minVersion: "1.0", softVersion: "1.0.0", installed: "1.0").softBanner)
    }

    func testForceBeatsSoftWhenBothFloorsMatchOrApply() {
        for (hard, soft, label) in [("2.0", "2.0", "matching floors"), ("2.0", "3.0", "both apply, soft higher"), ("3.0", "2.0", "both apply, hard higher")] {
            let decision = evaluate(minVersion: hard, softVersion: soft, installed: "1.0")
            XCTAssertNotNil(decision.force, label)
            XCTAssertNil(decision.softBanner, label)
            XCTAssertNil(decision.downtimeBanner, label)
        }
        let hardEqual = evaluate(minVersion: "1.0", softVersion: "2.0", installed: "1.0")
        XCTAssertNil(hardEqual.force, "hard equal to install does not force")
        XCTAssertNotNil(hardEqual.softBanner)
        let hardBelow = evaluate(minVersion: "0.9", softVersion: "2.0", installed: "1.0")
        XCTAssertNil(hardBelow.force, "hard below install leaves soft")
        XCTAssertNotNil(hardBelow.softBanner)
    }

    func testBannerWindowEdges() {
        let message = #"{"en":"Down tonight","sk":"Vecer","hu":"Ma este"}"#

        XCTAssertEqual(
            evaluate(bannerMessage: message, bannerStart: "", bannerEnd: "").downtimeBanner?.message,
            "Down tonight"
        )
        XCTAssertNil(evaluate(bannerMessage: "{}", bannerStart: "", bannerEnd: "").downtimeBanner)
        XCTAssertNil(evaluate(bannerMessage: "", bannerStart: "", bannerEnd: "").downtimeBanner)

        XCTAssertEqual(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T11:00:00Z",
                bannerEnd: "2026-11-05T13:00:00Z"
            ).downtimeBanner?.message,
            "Down tonight"
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T12:00:00Z",
                bannerEnd: "2026-11-05T13:00:00Z"
            ).downtimeBanner
        )
        XCTAssertNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T11:00:00Z",
                bannerEnd: "2026-11-05T12:00:00Z"
            ).downtimeBanner
        )
        XCTAssertNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T13:00:00Z",
                bannerEnd: "2026-11-05T14:00:00Z"
            ).downtimeBanner
        )
        XCTAssertNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T10:00:00Z",
                bannerEnd: "2026-11-05T11:00:00Z"
            ).downtimeBanner
        )
        XCTAssertNil(
            evaluate(bannerMessage: message, bannerStart: "2026-11-05T11:00:00Z", bannerEnd: "").downtimeBanner
        )
        XCTAssertNil(
            evaluate(bannerMessage: message, bannerStart: "", bannerEnd: "2026-11-05T13:00:00Z").downtimeBanner
        )
        XCTAssertNil(
            evaluate(bannerMessage: message, bannerStart: "tomorrow", bannerEnd: "later").downtimeBanner
        )
        XCTAssertNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T13:00:00Z",
                bannerEnd: "2026-11-05T11:00:00Z"
            ).downtimeBanner
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T13:00:00+02:00",
                bannerEnd: "2026-11-05T15:00:00+02:00"
            ).downtimeBanner
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T11:00:00.000Z",
                bannerEnd: "2026-11-05T13:00:00.500Z"
            ).downtimeBanner
        )
    }

    func testJSONLanguageFallbackThenCatalogFallback() {
        let json = #"{"en":"English","sk":"Slovak","hu":"Hungarian"}"#
        XCTAssertEqual(evaluate(blockingMessage: json, language: "sk", blocking: true).blocking?.body, .remote("Slovak"))
        XCTAssertEqual(evaluate(blockingMessage: json, language: "hu", blocking: true).blocking?.body, .remote("Hungarian"))
        XCTAssertEqual(evaluate(blockingMessage: json, language: "en", blocking: true).blocking?.body, .remote("English"))
        XCTAssertEqual(evaluate(blockingMessage: json, language: "fr", blocking: true).blocking?.body, .remote("English"))
        XCTAssertEqual(
            evaluate(blockingMessage: json, language: "sk-SK", blocking: true).blocking?.body,
            .remote("Slovak")
        )
        XCTAssertEqual(
            evaluate(blockingMessage: #"{"en":"English"}"#, language: "hu_HU", blocking: true).blocking?.body,
            .remote("English")
        )
        XCTAssertEqual(
            evaluate(blockingMessage: #"{"sk":"","en":"English"}"#, language: "sk", blocking: true).blocking?.body,
            .remote("English")
        )
        XCTAssertEqual(
            evaluate(blockingMessage: #"{"en":"  "}"#, language: "en", blocking: true).blocking?.body,
            .catalogFallback
        )
        XCTAssertEqual(evaluate(blockingMessage: "{}", language: "sk", blocking: true).blocking?.body, .catalogFallback)
        XCTAssertEqual(evaluate(blockingMessage: "", language: "en", blocking: true).blocking?.body, .catalogFallback)
        XCTAssertEqual(evaluate(blockingMessage: "not-json", language: "hu", blocking: true).blocking?.body, .catalogFallback)
        XCTAssertEqual(evaluate(blockingMessage: "[]", language: "en", blocking: true).blocking?.body, .catalogFallback)
        XCTAssertEqual(
            evaluate(blockingMessage: #"{"en":1}"#, language: "en", blocking: true).blocking?.body,
            .catalogFallback
        )

        XCTAssertEqual(evaluate(bannerMessage: json, language: "hu").downtimeBanner?.message, "Hungarian")
        XCTAssertEqual(evaluate(bannerMessage: #"{"sk":"Slovak"}"#, language: "fr").downtimeBanner?.message, nil)
        XCTAssertNil(evaluate(bannerMessage: "{}", language: "en").downtimeBanner)
    }

    func testSoftBannerDismissStoresThresholdAndStaysQuietUntilItChanges() {
        XCTAssertEqual(
            AppVersionPolicy.dismissedSoftVersionDefaultsKey,
            "minit.remoteConfig.dismissedSoftMinVersionIOS"
        )

        let shown = evaluate(softVersion: "1.2", installed: "1.0")
        XCTAssertEqual(shown.softBanner?.threshold, "1.2")
        XCTAssertNil(shown.force)

        let quiet = evaluate(softVersion: "1.2", installed: "1.0", dismissedSoft: shown.softBanner?.threshold)
        XCTAssertNil(quiet.softBanner)

        let padded = evaluate(softVersion: "  1.2  ", installed: "1.0", dismissedSoft: "1.2")
        XCTAssertNil(padded.softBanner)

        let changed = evaluate(softVersion: "1.3", installed: "1.0", dismissedSoft: "1.2")
        XCTAssertEqual(changed.softBanner?.threshold, "1.3")

        let stillThere = evaluate(
            bannerMessage: #"{"en":"Down tonight"}"#,
            softVersion: "1.2",
            installed: "1.0",
            dismissedSoft: "1.2"
        )
        XCTAssertNil(stillThere.softBanner)
        XCTAssertEqual(stillThere.downtimeBanner?.message, "Down tonight")
    }

    func testBannerDismissLastsUntilMessageOrWindowChanges() {
        let shown = evaluate(
            bannerMessage: #"{"en":"Down tonight"}"#,
            bannerStart: "2026-11-05T11:00:00Z",
            bannerEnd: "2026-11-05T13:00:00Z"
        )
        let identity = try? XCTUnwrap(shown.downtimeBanner?.identity)
        guard let identity else { return }

        XCTAssertNil(
            evaluate(
                bannerMessage: #"{"en":"Down tonight"}"#,
                bannerStart: "2026-11-05T11:00:00Z",
                bannerEnd: "2026-11-05T13:00:00Z",
                dismissedBanner: identity
            ).downtimeBanner
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: #"{"en":"Back at dawn"}"#,
                bannerStart: "2026-11-05T11:00:00Z",
                bannerEnd: "2026-11-05T13:00:00Z",
                dismissedBanner: identity
            ).downtimeBanner
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: #"{"en":"Down tonight"}"#,
                bannerStart: "2026-11-05T11:30:00Z",
                bannerEnd: "2026-11-05T13:00:00Z",
                dismissedBanner: identity
            ).downtimeBanner
        )
    }

    func testBannerDismissIdentityStaysStableAcrossLanguage() throws {
        let json = #"{"en":"English","sk":"Slovak"}"#
        let start = "2026-11-05T11:00:00Z"
        let end = "2026-11-05T13:00:00Z"
        let english = evaluate(bannerMessage: json, bannerStart: start, bannerEnd: end, language: "en")
        let identity = try XCTUnwrap(english.downtimeBanner?.identity)
        XCTAssertEqual(english.downtimeBanner?.message, "English")
        XCTAssertEqual(identity, AppVersionPolicy.bannerIdentity(message: json, start: start, end: end))
        XCTAssertNotEqual(identity, AppVersionPolicy.bannerIdentity(message: "English", start: start, end: end))

        let dismissedInSlovak = evaluate(
            bannerMessage: json,
            bannerStart: start,
            bannerEnd: end,
            language: "sk",
            dismissedBanner: identity
        )
        XCTAssertNil(dismissedInSlovak.downtimeBanner)

        let slovak = evaluate(bannerMessage: json, bannerStart: start, bannerEnd: end, language: "sk")
        XCTAssertEqual(slovak.downtimeBanner?.message, "Slovak")
        XCTAssertEqual(slovak.downtimeBanner?.identity, identity)

        let padded = evaluate(
            bannerMessage: " \n\(json)\n ",
            bannerStart: start,
            bannerEnd: end,
            language: "hu"
        )
        XCTAssertEqual(padded.downtimeBanner?.message, "English")
        XCTAssertEqual(padded.downtimeBanner?.identity, identity)
    }

    func testEveryChannelUsesTheSameMarketingKeys() {
        XCTAssertEqual(RemoteConfigKey.minVersionIOS, "min_version_ios")
        XCTAssertEqual(RemoteConfigKey.softMinVersionIOS, "soft_min_version_ios")
        XCTAssertEqual(RemoteConfigKey.minVersionAndroid, "min_version_android")
        XCTAssertEqual(RemoteConfigKey.softMinVersionAndroid, "soft_min_version_android")
        XCTAssertEqual(RemoteConfigFetchPolicy.minimumFetchInterval, 0)
        XCTAssertEqual(Set(RemoteConfigDefaults.firebaseValues.keys), Set(RemoteConfigKey.all))
        XCTAssertEqual(RemoteConfigDefaults.firebaseValues[RemoteConfigKey.minVersionIOS] as? String, "")
        XCTAssertEqual(RemoteConfigDefaults.firebaseValues[RemoteConfigKey.softMinVersionIOS] as? String, "")
        XCTAssertEqual(
            (RemoteConfigDefaults.firebaseValues[RemoteConfigKey.maintenanceBlocking] as? NSNumber)?.boolValue,
            false
        )

        let values: [String: String] = [
            RemoteConfigKey.minVersionIOS: "2.0",
            RemoteConfigKey.softMinVersionIOS: "1.5",
            RemoteConfigKey.minVersionAndroid: "9.9",
            RemoteConfigKey.softMinVersionAndroid: "9.9",
            RemoteConfigKey.updateURLIOS: "https://apps.apple.com/app/id1",
            "min_build_ios": "1000",
            "soft_min_build_ios": "1000",
            "CFBundleVersion": "1000",
        ]
        for channel in AppDistributionChannel.allCases {
            let decision = evaluate(values: values, channel: channel, installed: "1.0.0")
            let force = decision.force
            XCTAssertNotNil(force, "\(channel.rawValue) should force from min_version_ios")
            XCTAssertEqual(force?.usesTesterCopy, channel.usesTesterCopy, channel.rawValue)
            if channel == .release {
                guard case .openStore(let url) = force?.action else {
                    return XCTFail("\(channel.rawValue) should open the store")
                }
                XCTAssertEqual(url.absoluteString, "https://apps.apple.com/app/id1")
            } else {
                XCTAssertEqual(force?.action, .testerAlert, channel.rawValue)
            }
            XCTAssertNil(decision.softBanner)
            XCTAssertNil(decision.downtimeBanner)
        }

        let softValues: [String: String] = [
            RemoteConfigKey.minVersionIOS: "",
            RemoteConfigKey.softMinVersionIOS: "2.0",
            RemoteConfigKey.minVersionAndroid: "9.9",
            "min_build_ios": "1",
        ]
        for channel in AppDistributionChannel.allCases {
            let decision = evaluate(values: softValues, channel: channel, installed: "1.0")
            XCTAssertNotNil(decision.softBanner, "\(channel.rawValue) should soft-update from soft_min_version_ios")
            XCTAssertEqual(decision.softBanner?.usesTesterCopy, channel.usesTesterCopy, channel.rawValue)
            XCTAssertNil(decision.force, channel.rawValue)
        }

        let androidOnly: [String: String] = [
            RemoteConfigKey.minVersionIOS: "",
            RemoteConfigKey.minVersionAndroid: "99.0",
            "min_build_ios": "999",
        ]
        for channel in AppDistributionChannel.allCases {
            let decision = evaluate(values: androidOnly, channel: channel, installed: "1.0")
            XCTAssertNil(decision.force, channel.rawValue)
            XCTAssertNil(decision.softBanner, channel.rawValue)
        }

        XCTAssertEqual(
            InstalledAppVersion.marketingVersion(infoDictionary: [
                "CFBundleShortVersionString": "1.4",
                "CFBundleVersion": "88",
            ]),
            "1.4"
        )
        XCTAssertNil(
            evaluate(values: [
                RemoteConfigKey.minVersionIOS: "1.0",
                "min_build_ios": "999",
            ], installed: "1.0.0").force
        )
    }

    func testReleaseUpdateURLOpensOnlyWhenSet() {
        let withURL = evaluate(
            minVersion: "2.0",
            updateURL: " https://apps.apple.com/app/id9 ",
            channel: .release,
            installed: "1.0"
        ).force
        guard case .openStore(let url) = withURL?.action else {
            return XCTFail("force")
        }
        XCTAssertEqual(url.absoluteString, "https://apps.apple.com/app/id9")
        XCTAssertEqual(withURL?.usesTesterCopy, false)

        XCTAssertEqual(
            evaluate(minVersion: "2.0", updateURL: "  ", channel: .release, installed: "1.0").force?.action,
            .unavailable
        )
        XCTAssertEqual(
            evaluate(minVersion: "2.0", updateURL: "not a url", channel: .release, installed: "1.0").force?.action,
            .unavailable
        )

        for channel in [AppDistributionChannel.development, .internal] {
            let force = evaluate(
                minVersion: "2.0",
                updateURL: "https://apps.apple.com/app/id9",
                channel: channel,
                installed: "1.0"
            ).force
            XCTAssertEqual(force?.action, .testerAlert, channel.rawValue)
            XCTAssertEqual(force?.usesTesterCopy, true, channel.rawValue)
        }
    }

    func testSoftBannerUpdateUsesTheSameActionAsForceUpdate() {
        let store = AppVersionPolicy.UpdateAction.openStore(URL(string: "https://apps.apple.com/app/id9")!)
        let cases: [(AppDistributionChannel, String, AppVersionPolicy.UpdateAction)] = [
            (.release, "https://apps.apple.com/app/id9", store),
            (.release, "  ", .unavailable),
            (.release, "http://apps.apple.com/app/id9", .unavailable),
            (.development, "https://apps.apple.com/app/id9", .testerAlert),
            (.internal, "https://apps.apple.com/app/id9", .testerAlert),
            (.internal, "", .testerAlert),
        ]
        for (channel, url, expected) in cases {
            let force = evaluate(
                minVersion: "2.0",
                updateURL: url,
                channel: channel,
                installed: "1.0"
            ).force
            let soft = evaluate(
                softVersion: "2.0",
                updateURL: url,
                channel: channel,
                installed: "1.0"
            ).softBanner
            XCTAssertEqual(force?.action, expected, "\(channel.rawValue) force \(url)")
            XCTAssertEqual(soft?.action, expected, "\(channel.rawValue) soft \(url)")
            XCTAssertEqual(soft?.action, force?.action, channel.rawValue)
            XCTAssertEqual(soft?.usesTesterCopy, channel.usesTesterCopy, channel.rawValue)
            XCTAssertNil(
                evaluate(softVersion: "2.0", updateURL: url, channel: channel, installed: "1.0").force,
                channel.rawValue
            )
        }

        guard case .openStore(let trimmed) = evaluate(
            softVersion: "2.0",
            updateURL: " https://apps.apple.com/app/id9 ",
            channel: .release,
            installed: "1.0"
        ).softBanner?.action else {
            return XCTFail("trimmed url")
        }
        XCTAssertEqual(trimmed.absoluteString, "https://apps.apple.com/app/id9")

        guard case .openStore(let appStore) = evaluate(
            softVersion: "2.0",
            updateURL: "itms-apps://apps.apple.com/app/id9",
            channel: .release,
            installed: "1.0"
        ).softBanner?.action else {
            return XCTFail("itms-apps")
        }
        XCTAssertEqual(appStore.scheme?.lowercased(), "itms-apps")
    }

    func testReleaseUpdateURLAllowsOnlyHTTPSAndAppStoreSchemes() {
        let allowed = [
            "https://apps.apple.com/app/id9",
            "HTTPS://apps.apple.com/app/id9",
            "itms-apps://apps.apple.com/app/id9",
            "ITMS-APPS://apps.apple.com/app/id9",
        ]
        for raw in allowed {
            guard case .openStore(let url) = evaluate(
                minVersion: "2.0",
                updateURL: " \(raw) ",
                channel: .release,
                installed: "1.0"
            ).force?.action else {
                return XCTFail(raw)
            }
            XCTAssertEqual(url.scheme?.lowercased(), URL(string: raw)?.scheme?.lowercased(), raw)
        }

        let rejected = [
            "http://apps.apple.com/app/id9",
            "HTTP://apps.apple.com/app/id9",
            "tel:123456",
            "minit://update",
            "javascript:alert(1)",
            "file:///tmp/app",
        ]
        for raw in rejected {
            XCTAssertEqual(
                evaluate(minVersion: "2.0", updateURL: raw, channel: .release, installed: "1.0").force?.action,
                .unavailable,
                raw
            )
        }
    }

    func testGatePrecedence() {
        let floorsAndBanner: [String: String] = [
            RemoteConfigKey.maintenanceBlockingMessage: #"{"en":"Closed"}"#,
            RemoteConfigKey.maintenanceBannerMessage: #"{"en":"Tonight"}"#,
            RemoteConfigKey.minVersionIOS: "9.0",
            RemoteConfigKey.softMinVersionIOS: "8.0",
        ]

        let blocking = evaluate(values: floorsAndBanner, installed: "1.0", blocking: true)
        XCTAssertEqual(blocking.blocking?.body, .remote("Closed"))
        XCTAssertNil(blocking.force)
        XCTAssertNil(blocking.softBanner)
        XCTAssertNil(blocking.downtimeBanner)
        XCTAssertTrue(blocking.coversApp)

        let force = evaluate(values: floorsAndBanner, installed: "1.0", blocking: false)
        XCTAssertNotNil(force.force)
        XCTAssertNil(force.softBanner)
        XCTAssertNil(force.downtimeBanner)
        XCTAssertNil(force.blocking)
        XCTAssertTrue(force.coversApp)

        var softValues = floorsAndBanner
        softValues[RemoteConfigKey.minVersionIOS] = ""
        let soft = evaluate(values: softValues, installed: "1.0")
        XCTAssertNotNil(soft.softBanner)
        XCTAssertNil(soft.force)
        XCTAssertEqual(soft.downtimeBanner?.message, "Tonight")
        XCTAssertNil(soft.blocking)
        XCTAssertFalse(soft.coversApp)

        let banner = evaluate(
            values: [
                RemoteConfigKey.maintenanceBannerMessage: #"{"en":"Tonight"}"#,
            ],
            installed: "1.0"
        )
        XCTAssertNil(banner.force)
        XCTAssertNil(banner.softBanner)
        XCTAssertEqual(banner.downtimeBanner?.message, "Tonight")

        XCTAssertEqual(evaluate(installed: "1.0"), AppVersionPolicy.Decision.clear)
    }

    func testInAppDefaultsLeaveEveryGateOff() {
        let decision = AppVersionPolicy.evaluate(
            AppVersionPolicy.Input(
                snapshot: .defaults,
                channel: .internal,
                installedMarketingVersion: "0.1",
                languageCode: "en",
                now: now,
                dismissedSoftThreshold: nil,
                dismissedBannerIdentity: nil
            )
        )
        XCTAssertEqual(decision, AppVersionPolicy.Decision.clear)
    }

    func testMaintenanceReloadClearedWhenFetchActivatesOff() {
        let cached = reloadSnapshot(blocking: true)
        let activated = reloadSnapshot(
            blocking: false,
            minVersion: "9.0",
            softVersion: "8.0",
            bannerMessage: #"{"en":"Tonight"}"#
        )
        let resolution = AppVersionPolicy.resolveMaintenanceReload(
            fetchSucceeded: true,
            activated: activated,
            cached: cached
        )
        XCTAssertEqual(resolution.outcome, AppVersionPolicy.MaintenanceReloadOutcome.cleared)
        XCTAssertEqual(resolution.snapshot, activated)
        let decision = evaluate(snapshot: resolution.snapshot)
        XCTAssertNil(decision.blocking)
        XCTAssertNotNil(decision.force)
        XCTAssertNil(decision.softBanner)
        XCTAssertNil(decision.downtimeBanner)
        XCTAssertTrue(decision.coversApp)
    }

    func testMaintenanceReloadStillActiveWhenFetchKeepsBlocking() {
        let cached = reloadSnapshot(blocking: false, minVersion: "9.0")
        let activated = reloadSnapshot(
            blocking: true,
            blockingMessage: #"{"en":"Closed"}"#,
            minVersion: "9.0",
            bannerMessage: #"{"en":"Tonight"}"#
        )
        let resolution = AppVersionPolicy.resolveMaintenanceReload(
            fetchSucceeded: true,
            activated: activated,
            cached: cached
        )
        XCTAssertEqual(resolution.outcome, AppVersionPolicy.MaintenanceReloadOutcome.stillUnavailable)
        XCTAssertEqual(resolution.snapshot, activated)
        let decision = evaluate(snapshot: resolution.snapshot)
        XCTAssertEqual(decision.blocking?.body, AppVersionPolicy.ResolvedText.remote("Closed"))
        XCTAssertNil(decision.force)
        XCTAssertNil(decision.softBanner)
        XCTAssertNil(decision.downtimeBanner)
        XCTAssertTrue(decision.coversApp)
    }

    func testMaintenanceReloadFetchFailedCachedActiveStaysUnavailable() {
        let cached = reloadSnapshot(blocking: true, blockingMessage: #"{"en":"Closed"}"#)
        let activated = reloadSnapshot(
            blocking: false,
            minVersion: "9.0",
            bannerMessage: #"{"en":"Tonight"}"#
        )
        let resolution = AppVersionPolicy.resolveMaintenanceReload(
            fetchSucceeded: false,
            activated: activated,
            cached: cached
        )
        XCTAssertEqual(resolution.outcome, AppVersionPolicy.MaintenanceReloadOutcome.stillUnavailable)
        XCTAssertEqual(resolution.snapshot, cached)
        XCTAssertNotEqual(resolution.snapshot, activated)
        let decision = evaluate(snapshot: resolution.snapshot)
        XCTAssertEqual(decision.blocking?.body, AppVersionPolicy.ResolvedText.remote("Closed"))
        XCTAssertNil(decision.force)
        XCTAssertNil(decision.downtimeBanner)
    }

    func testMaintenanceReloadFetchFailedCachedClearedDismisses() {
        let cached = reloadSnapshot(
            blocking: false,
            softVersion: "8.0",
            bannerMessage: #"{"en":"Tonight"}"#
        )
        let activated = reloadSnapshot(
            blocking: true,
            blockingMessage: #"{"en":"Closed"}"#,
            minVersion: "9.0"
        )
        let resolution = AppVersionPolicy.resolveMaintenanceReload(
            fetchSucceeded: false,
            activated: activated,
            cached: cached
        )
        XCTAssertEqual(resolution.outcome, AppVersionPolicy.MaintenanceReloadOutcome.cleared)
        XCTAssertEqual(resolution.snapshot, cached)
        XCTAssertFalse(resolution.snapshot.maintenanceBlocking)
        let decision = evaluate(snapshot: resolution.snapshot)
        XCTAssertNil(decision.blocking)
        XCTAssertNil(decision.force)
        XCTAssertNotNil(decision.softBanner)
        XCTAssertEqual(decision.downtimeBanner?.message, "Tonight")
        XCTAssertFalse(decision.coversApp)
    }

    func testRequestInviteMailIncludesPlatformAndInstalledVersion() throws {
        XCTAssertEqual(
            RemoteConfigTesterMail.addressURL()?.absoluteString,
            "mailto:armands.berzins@saleseverest.com"
        )
        for language in ["en", "sk", "hu"] {
            let template = AppLocalizedString.string(
                RemoteConfigCopy.requestBody,
                locale: Locale(identifier: language)
            )
            let body = RemoteConfigTesterMail.requestBody(template: template, installedVersion: "1.4")
            XCTAssertTrue(body.contains("iOS"), language)
            XCTAssertTrue(body.contains("1.4"), language)
            let subject = AppLocalizedString.string(
                RemoteConfigCopy.requestSubject,
                locale: Locale(identifier: language)
            )
            let url = try XCTUnwrap(RemoteConfigTesterMail.requestInviteURL(subject: subject, body: body))
            XCTAssertEqual(url.scheme, "mailto")
            XCTAssertTrue(url.absoluteString.contains("armands.berzins@saleseverest.com"), url.absoluteString)
            let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            XCTAssertEqual(items.first { $0.name == "subject" }?.value, subject)
            let decoded = try XCTUnwrap(items.first { $0.name == "body" }?.value)
            XCTAssertTrue(decoded.contains("iOS"), decoded)
            XCTAssertTrue(decoded.contains("1.4"), decoded)
            XCTAssertTrue(url.absoluteString.hasPrefix("mailto:\(RemoteConfigTesterMail.email)?"), url.absoluteString)
        }
    }

    func testRequestInviteURLEncodesReservedQueryCharacters() throws {
        let subject = "A&B+C=D"
        let body = "line1\nline2 & more+equals=yes"
        let url = try XCTUnwrap(RemoteConfigTesterMail.requestInviteURL(subject: subject, body: body))
        let absolute = url.absoluteString
        XCTAssertTrue(absolute.hasPrefix("mailto:\(RemoteConfigTesterMail.email)?"))
        XCTAssertFalse(absolute.contains("mailto:/"))
        let query = String(absolute.split(separator: "?", maxSplits: 1)[1])
        XCTAssertEqual(query.filter { $0 == "&" }.count, 1)
        XCTAssertTrue(query.contains("%26"))
        XCTAssertTrue(query.contains("%2B"))
        XCTAssertTrue(query.contains("%3D"))
        XCTAssertTrue(query.contains("%0A"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "subject" }?.value, subject)
        XCTAssertEqual(items.first { $0.name == "body" }?.value, body)
    }

    func testChannelResolutionUsesSentryEnvironment() {
        XCTAssertEqual(AppDistributionChannel.resolve(environment: "development", fallback: .release), .development)
        XCTAssertEqual(AppDistributionChannel.resolve(environment: "internal", fallback: .release), .internal)
        XCTAssertEqual(AppDistributionChannel.resolve(environment: "release", fallback: .development), .release)
        XCTAssertEqual(AppDistributionChannel.resolve(environment: nil, fallback: .development), .development)
        XCTAssertEqual(AppDistributionChannel.resolve(environment: "$(SENTRY_ENVIRONMENT)", fallback: .release), .release)
        XCTAssertEqual(AppDistributionChannel.resolve(environment: "unknown", fallback: .release), .release)
    }

    func testCatalogChromeMatchesPlan() {
        let expected: [String: [String: String]] = [
            RemoteConfigCopy.blockingTitle: [
                "en": "Minit is unavailable",
                "sk": "Minit nie je dostupný",
                "hu": "A Minit nem érhető el",
            ],
            RemoteConfigCopy.blockingFallback: [
                "en": "Minit is temporarily unavailable. Please try again later.",
                "sk": "Minit je dočasne nedostupný. Skúste to znova neskôr.",
                "hu": "A Minit átmenetileg nem érhető el. Próbáld újra később.",
            ],
            RemoteConfigCopy.forceTitle: [
                "en": "Please update the app",
                "sk": "Aktualizujte aplikáciu, prosím",
                "hu": "Frissítsd az alkalmazást",
            ],
            RemoteConfigCopy.forceReleaseBody: [
                "en": "This version of Minit is no longer supported. Update to keep using the app.",
                "sk": "Táto verzia aplikácie Minit už nie je podporovaná. Aktualizujte ju, aby ste mohli aplikáciu naďalej používať.",
                "hu": "A Minit ezen verziója már nem támogatott. Frissíts, hogy tovább használhasd az alkalmazást.",
            ],
            RemoteConfigCopy.softTitle: [
                "en": "Update available",
                "sk": "K dispozícii je aktualizácia",
                "hu": "Frissítés érhető el",
            ],
            RemoteConfigCopy.softReleaseBody: [
                "en": "A newer version of Minit is available.",
                "sk": "K dispozícii je novšia verzia aplikácie Minit.",
                "hu": "A Minit újabb verziója érhető el.",
            ],
            RemoteConfigCopy.testerBody: [
                "en": "This test build is out of date. Check Firebase App Tester or your email for a newer build, or contact armands.berzins@saleseverest.com for an invite.",
                "sk": "Toto testovacie zostavenie je zastarané. Novšie zostavenie nájdete vo Firebase App Tester alebo vo svojom e-maile, prípadne požiadajte o pozvánku na adrese armands.berzins@saleseverest.com.",
                "hu": "Ez a tesztverzió elavult. Az újabb buildet a Firebase App Testerben vagy az e-mailjeid között találod, meghívóért pedig írj az armands.berzins@saleseverest.com címre.",
            ],
            RemoteConfigCopy.updateButton: [
                "en": "Update",
                "sk": "Aktualizovať",
                "hu": "Frissítés",
            ],
            RemoteConfigCopy.softTesterBody: [
                "en": "A newer test build is available. Check Firebase App Tester or your email.",
                "sk": "K dispozícii je novšie testovacie zostavenie. Nájdete ho vo Firebase App Tester alebo vo svojom e-maile.",
                "hu": "Elérhető egy újabb tesztverzió. A Firebase App Testerben vagy az e-mailjeid között találod.",
            ],
            RemoteConfigCopy.dismissBanner: [
                "en": "Dismiss",
                "sk": "Zavrieť",
                "hu": "Bezárás",
            ],
            RemoteConfigCopy.downtimeTitle: [
                "en": "Maintenance",
                "sk": "Údržba",
                "hu": "Karbantartás",
            ],
            RemoteConfigCopy.alertTitle: [
                "en": "Internal test build",
                "sk": "Interné testovacie zostavenie",
                "hu": "Belső tesztverzió",
            ],
            RemoteConfigCopy.alertMessage: [
                "en": "This is an internal test build. Testers get the new version by email or in Firebase App Tester. If you are not a tester, write to Armands for an invite.",
                "sk": "Toto je interné testovacie zostavenie. Testéri dostanú novú verziu e-mailom alebo vo Firebase App Tester. Ak nie ste tester, napíšte Armandsovi a požiadajte o pozvánku.",
                "hu": "Ez egy belső tesztverzió. A tesztelők e-mailben vagy a Firebase App Testerben kapják meg az új verziót. Ha nem vagy tesztelő, írj Armandsnak meghívóért.",
            ],
            RemoteConfigCopy.openMail: [
                "en": "Open mail",
                "sk": "Otvoriť poštu",
                "hu": "Levelek megnyitása",
            ],
            RemoteConfigCopy.requestVersion: [
                "en": "Request new version",
                "sk": "Požiadať o novú verziu",
                "hu": "Új verzió kérése",
            ],
            RemoteConfigCopy.alertCancel: [
                "en": "Cancel",
                "sk": "Zrušiť",
                "hu": "Mégse",
            ],
            RemoteConfigCopy.requestSubject: [
                "en": "Minit test version invite",
                "sk": "Pozvánka na testovaciu verziu Minit",
                "hu": "Meghívó a Minit tesztverziójához",
            ],
            RemoteConfigCopy.requestBody: [
                "en": "Hello,\n\nPlease send me an invite to the new Minit test version.\n\nPlatform: iOS\nInstalled version: %@\n",
                "sk": "Dobrý deň,\n\nProsím o pozvánku na novú testovaciu verziu aplikácie Minit.\n\nPlatforma: iOS\nNainštalovaná verzia: %@\n",
                "hu": "Szia,\n\nKérlek, küldj meghívót a Minit új tesztverziójához.\n\nPlatform: iOS\nTelepített verzió: %@\n",
            ],
            RemoteConfigCopy.reloadButton: [
                "en": "Reload",
                "sk": "Obnoviť",
                "hu": "Újratöltés",
            ],
            RemoteConfigCopy.stillUnavailableMessage: [
                "en": "Sorry, Minit app is still unavailable right now. Please try again later.",
                "sk": "Prepáčte, aplikácia Minit je stále nedostupná. Skúste to znova neskôr.",
                "hu": "Sajnos a Minit alkalmazás még mindig nem érhető el. Próbáld újra később.",
            ],
            RemoteConfigCopy.stillUnavailableOK: [
                "en": "OK",
                "sk": "OK",
                "hu": "OK",
            ],
        ]

        for (key, translations) in expected {
            for (language, value) in translations {
                XCTAssertEqual(
                    AppLocalizedString.string(key, locale: Locale(identifier: language)),
                    value,
                    "\(key) \(language)"
                )
            }
        }
    }

    private func reloadSnapshot(
        blocking: Bool,
        blockingMessage: String = "{}",
        minVersion: String = "",
        softVersion: String = "",
        bannerMessage: String = "{}"
    ) -> RemoteConfigSnapshot {
        RemoteConfigSnapshot(
            maintenanceBlocking: blocking,
            maintenanceBlockingMessage: blockingMessage,
            maintenanceBannerMessage: bannerMessage,
            maintenanceBannerStart: "",
            maintenanceBannerEnd: "",
            minVersionIOS: minVersion,
            softMinVersionIOS: softVersion,
            updateURLIOS: ""
        )
    }

    private func evaluate(snapshot: RemoteConfigSnapshot, installed: String = "1.0") -> AppVersionPolicy.Decision {
        AppVersionPolicy.evaluate(
            AppVersionPolicy.Input(
                snapshot: snapshot,
                channel: .release,
                installedMarketingVersion: installed,
                languageCode: "en",
                now: now,
                dismissedSoftThreshold: nil,
                dismissedBannerIdentity: nil
            )
        )
    }

    private func evaluate(
        values: [String: String]? = nil,
        blockingMessage: String = "{}",
        bannerMessage: String = "{}",
        bannerStart: String = "",
        bannerEnd: String = "",
        minVersion: String = "",
        softVersion: String = "",
        updateURL: String = "",
        channel: AppDistributionChannel = .release,
        installed: String = "1.0.0",
        language: String = "en",
        blocking: Bool = false,
        dismissedSoft: String? = nil,
        dismissedBanner: String? = nil
    ) -> AppVersionPolicy.Decision {
        let snapshot: RemoteConfigSnapshot
        if var values {
            values[RemoteConfigKey.maintenanceBlockingMessage] = values[RemoteConfigKey.maintenanceBlockingMessage] ?? blockingMessage
            values[RemoteConfigKey.maintenanceBannerMessage] = values[RemoteConfigKey.maintenanceBannerMessage] ?? bannerMessage
            values[RemoteConfigKey.maintenanceBannerStart] = values[RemoteConfigKey.maintenanceBannerStart] ?? bannerStart
            values[RemoteConfigKey.maintenanceBannerEnd] = values[RemoteConfigKey.maintenanceBannerEnd] ?? bannerEnd
            if values[RemoteConfigKey.minVersionIOS] == nil { values[RemoteConfigKey.minVersionIOS] = minVersion }
            if values[RemoteConfigKey.softMinVersionIOS] == nil { values[RemoteConfigKey.softMinVersionIOS] = softVersion }
            if values[RemoteConfigKey.updateURLIOS] == nil { values[RemoteConfigKey.updateURLIOS] = updateURL }
            snapshot = RemoteConfigSnapshot(values: values, maintenanceBlocking: blocking)
        } else {
            snapshot = RemoteConfigSnapshot(
                maintenanceBlocking: blocking,
                maintenanceBlockingMessage: blockingMessage,
                maintenanceBannerMessage: bannerMessage,
                maintenanceBannerStart: bannerStart,
                maintenanceBannerEnd: bannerEnd,
                minVersionIOS: minVersion,
                softMinVersionIOS: softVersion,
                updateURLIOS: updateURL
            )
        }
        return AppVersionPolicy.evaluate(
            AppVersionPolicy.Input(
                snapshot: snapshot,
                channel: channel,
                installedMarketingVersion: installed,
                languageCode: language,
                now: now,
                dismissedSoftThreshold: dismissedSoft,
                dismissedBannerIdentity: dismissedBanner
            )
        )
    }
}
