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

        XCTAssertNil(evaluate(minVersion: "1.0.0", installed: "1.0").update)
        XCTAssertNil(evaluate(minVersion: "1.0", installed: "1.0.0").update)
        XCTAssertNil(evaluate(softVersion: "1.0.0", installed: "1.0").update)
        XCTAssertNil(evaluate(minVersion: "1", installed: "1.0.0").update)

        guard case .force = evaluate(minVersion: "1.0.1", installed: "1.0").update else {
            return XCTFail("1.0.1 is above 1.0")
        }
        guard case .soft = evaluate(softVersion: "1.0.1", installed: "1.0").update else {
            return XCTFail("soft 1.0.1 is above 1.0")
        }
        guard case .force = evaluate(minVersion: "1.10", installed: "1.2").update else {
            return XCTFail("1.10 is above 1.2")
        }
        XCTAssertNil(evaluate(minVersion: "1.2", installed: "1.10").update)
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
            XCTAssertNil(decision.update, installed)
            XCTAssertNil(decision.blocking, installed)
            XCTAssertEqual(decision.banner?.message, "Tonight", installed)
        }

        let blocking = evaluate(
            blockingMessage: #"{"en":"Closed"}"#,
            minVersion: "9.0",
            softVersion: "9.0",
            installed: "not-a-version",
            blocking: true
        )
        XCTAssertEqual(blocking.blocking?.body, .remote("Closed"))
        XCTAssertNil(blocking.update)
    }

    func testBlankOrInvalidFloorTurnsThatComparatorOff() {
        guard case .soft(let prompt) = evaluate(minVersion: "", softVersion: "2.0", installed: "1.0").update else {
            return XCTFail("blank hard floor leaves soft on")
        }
        XCTAssertEqual(prompt.softThreshold, "2.0")

        guard case .soft = evaluate(minVersion: "nope", softVersion: "2.0", installed: "1.0").update else {
            return XCTFail("invalid hard floor leaves soft on")
        }
        guard case .force = evaluate(minVersion: "2.0", softVersion: "", installed: "1.0").update else {
            return XCTFail("blank soft floor leaves force on")
        }
        guard case .force = evaluate(minVersion: "2.0", softVersion: "soon", installed: "1.0").update else {
            return XCTFail("invalid soft floor leaves force on")
        }
        XCTAssertNil(evaluate(minVersion: "", softVersion: "", installed: "1.0").update)
        XCTAssertNil(evaluate(minVersion: " ", softVersion: "x", installed: "1.0").update)
        XCTAssertNil(evaluate(minVersion: "1.0", softVersion: "1.0.0", installed: "1.0").update)
    }

    func testForceBeatsSoftWhenBothFloorsMatchOrApply() {
        guard case .force = evaluate(minVersion: "2.0", softVersion: "2.0", installed: "1.0").update else {
            return XCTFail("matching floors")
        }
        guard case .force = evaluate(minVersion: "2.0", softVersion: "3.0", installed: "1.0").update else {
            return XCTFail("both apply, soft higher")
        }
        guard case .force = evaluate(minVersion: "3.0", softVersion: "2.0", installed: "1.0").update else {
            return XCTFail("both apply, hard higher")
        }
        guard case .soft = evaluate(minVersion: "1.0", softVersion: "2.0", installed: "1.0").update else {
            return XCTFail("hard equal to install does not force")
        }
        guard case .soft = evaluate(minVersion: "0.9", softVersion: "2.0", installed: "1.0").update else {
            return XCTFail("hard below install leaves soft")
        }
    }

    func testBannerWindowEdges() {
        let message = #"{"en":"Down tonight","sk":"Vecer","hu":"Ma este"}"#

        XCTAssertEqual(
            evaluate(bannerMessage: message, bannerStart: "", bannerEnd: "").banner?.message,
            "Down tonight"
        )
        XCTAssertNil(evaluate(bannerMessage: "{}", bannerStart: "", bannerEnd: "").banner)
        XCTAssertNil(evaluate(bannerMessage: "", bannerStart: "", bannerEnd: "").banner)

        XCTAssertEqual(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T11:00:00Z",
                bannerEnd: "2026-11-05T13:00:00Z"
            ).banner?.message,
            "Down tonight"
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T12:00:00Z",
                bannerEnd: "2026-11-05T13:00:00Z"
            ).banner
        )
        XCTAssertNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T11:00:00Z",
                bannerEnd: "2026-11-05T12:00:00Z"
            ).banner
        )
        XCTAssertNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T13:00:00Z",
                bannerEnd: "2026-11-05T14:00:00Z"
            ).banner
        )
        XCTAssertNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T10:00:00Z",
                bannerEnd: "2026-11-05T11:00:00Z"
            ).banner
        )
        XCTAssertNil(
            evaluate(bannerMessage: message, bannerStart: "2026-11-05T11:00:00Z", bannerEnd: "").banner
        )
        XCTAssertNil(
            evaluate(bannerMessage: message, bannerStart: "", bannerEnd: "2026-11-05T13:00:00Z").banner
        )
        XCTAssertNil(
            evaluate(bannerMessage: message, bannerStart: "tomorrow", bannerEnd: "later").banner
        )
        XCTAssertNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T13:00:00Z",
                bannerEnd: "2026-11-05T11:00:00Z"
            ).banner
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T13:00:00+02:00",
                bannerEnd: "2026-11-05T15:00:00+02:00"
            ).banner
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: message,
                bannerStart: "2026-11-05T11:00:00.000Z",
                bannerEnd: "2026-11-05T13:00:00.500Z"
            ).banner
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

        XCTAssertEqual(evaluate(bannerMessage: json, language: "hu").banner?.message, "Hungarian")
        XCTAssertEqual(evaluate(bannerMessage: #"{"sk":"Slovak"}"#, language: "fr").banner?.message, nil)
        XCTAssertNil(evaluate(bannerMessage: "{}", language: "en").banner)
    }

    func testLaterStoresSoftThresholdAndStaysQuietUntilItChanges() {
        XCTAssertEqual(
            AppVersionPolicy.dismissedSoftVersionDefaultsKey,
            "minit.remoteConfig.dismissedSoftMinVersionIOS"
        )

        let shown = evaluate(softVersion: "1.2", installed: "1.0")
        guard case .soft(let prompt) = shown.update else {
            return XCTFail("soft prompt")
        }
        XCTAssertEqual(prompt.softThreshold, "1.2")

        let quiet = evaluate(softVersion: "1.2", installed: "1.0", dismissedSoft: prompt.softThreshold)
        XCTAssertNil(quiet.update)

        let padded = evaluate(softVersion: "  1.2  ", installed: "1.0", dismissedSoft: "1.2")
        XCTAssertNil(padded.update)

        let changed = evaluate(softVersion: "1.3", installed: "1.0", dismissedSoft: "1.2")
        guard case .soft(let again) = changed.update else {
            return XCTFail("new threshold shows again")
        }
        XCTAssertEqual(again.softThreshold, "1.3")

        let stillThere = evaluate(
            bannerMessage: #"{"en":"Down tonight"}"#,
            softVersion: "1.2",
            installed: "1.0",
            dismissedSoft: "1.2"
        )
        XCTAssertNil(stillThere.update)
        XCTAssertEqual(stillThere.banner?.message, "Down tonight")
    }

    func testBannerDismissLastsUntilMessageOrWindowChanges() {
        let shown = evaluate(
            bannerMessage: #"{"en":"Down tonight"}"#,
            bannerStart: "2026-11-05T11:00:00Z",
            bannerEnd: "2026-11-05T13:00:00Z"
        )
        let identity = try? XCTUnwrap(shown.banner?.identity)
        guard let identity else { return }

        XCTAssertNil(
            evaluate(
                bannerMessage: #"{"en":"Down tonight"}"#,
                bannerStart: "2026-11-05T11:00:00Z",
                bannerEnd: "2026-11-05T13:00:00Z",
                dismissedBanner: identity
            ).banner
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: #"{"en":"Back at dawn"}"#,
                bannerStart: "2026-11-05T11:00:00Z",
                bannerEnd: "2026-11-05T13:00:00Z",
                dismissedBanner: identity
            ).banner
        )
        XCTAssertNotNil(
            evaluate(
                bannerMessage: #"{"en":"Down tonight"}"#,
                bannerStart: "2026-11-05T11:30:00Z",
                bannerEnd: "2026-11-05T13:00:00Z",
                dismissedBanner: identity
            ).banner
        )
    }

    func testBannerDismissIdentityStaysStableAcrossLanguage() throws {
        let json = #"{"en":"English","sk":"Slovak"}"#
        let start = "2026-11-05T11:00:00Z"
        let end = "2026-11-05T13:00:00Z"
        let english = evaluate(bannerMessage: json, bannerStart: start, bannerEnd: end, language: "en")
        let identity = try XCTUnwrap(english.banner?.identity)
        XCTAssertEqual(english.banner?.message, "English")
        XCTAssertEqual(identity, AppVersionPolicy.bannerIdentity(message: json, start: start, end: end))
        XCTAssertNotEqual(identity, AppVersionPolicy.bannerIdentity(message: "English", start: start, end: end))

        let dismissedInSlovak = evaluate(
            bannerMessage: json,
            bannerStart: start,
            bannerEnd: end,
            language: "sk",
            dismissedBanner: identity
        )
        XCTAssertNil(dismissedInSlovak.banner)

        let slovak = evaluate(bannerMessage: json, bannerStart: start, bannerEnd: end, language: "sk")
        XCTAssertEqual(slovak.banner?.message, "Slovak")
        XCTAssertEqual(slovak.banner?.identity, identity)

        let padded = evaluate(
            bannerMessage: " \n\(json)\n ",
            bannerStart: start,
            bannerEnd: end,
            language: "hu"
        )
        XCTAssertEqual(padded.banner?.message, "English")
        XCTAssertEqual(padded.banner?.identity, identity)
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
            guard case .force(let prompt) = decision.update else {
                return XCTFail("\(channel.rawValue) should force from min_version_ios")
            }
            XCTAssertEqual(prompt.usesTesterCopy, channel != .release, channel.rawValue)
            if channel == .release {
                XCTAssertEqual(prompt.updateURL?.absoluteString, "https://apps.apple.com/app/id1")
            } else {
                XCTAssertNil(prompt.updateURL, channel.rawValue)
            }
            XCTAssertNil(decision.banner)
        }

        let softValues: [String: String] = [
            RemoteConfigKey.minVersionIOS: "",
            RemoteConfigKey.softMinVersionIOS: "2.0",
            RemoteConfigKey.minVersionAndroid: "9.9",
            "min_build_ios": "1",
        ]
        for channel in AppDistributionChannel.allCases {
            guard case .soft = evaluate(values: softValues, channel: channel, installed: "1.0").update else {
                return XCTFail("\(channel.rawValue) should soft-update from soft_min_version_ios")
            }
        }

        let androidOnly: [String: String] = [
            RemoteConfigKey.minVersionIOS: "",
            RemoteConfigKey.minVersionAndroid: "99.0",
            "min_build_ios": "999",
        ]
        for channel in AppDistributionChannel.allCases {
            XCTAssertNil(evaluate(values: androidOnly, channel: channel, installed: "1.0").update, channel.rawValue)
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
            ], installed: "1.0.0").update
        )
    }

    func testReleaseUpdateURLOpensOnlyWhenSet() {
        guard case .force(let withURL) = evaluate(
            minVersion: "2.0",
            updateURL: " https://apps.apple.com/app/id9 ",
            channel: .release,
            installed: "1.0"
        ).update else {
            return XCTFail("force")
        }
        XCTAssertEqual(withURL.updateURL?.absoluteString, "https://apps.apple.com/app/id9")
        XCTAssertFalse(withURL.usesTesterCopy)

        guard case .force(let empty) = evaluate(minVersion: "2.0", updateURL: "  ", channel: .release, installed: "1.0").update else {
            return XCTFail("force without url")
        }
        XCTAssertNil(empty.updateURL)

        guard case .force(let invalid) = evaluate(minVersion: "2.0", updateURL: "not a url", channel: .release, installed: "1.0").update else {
            return XCTFail("force with invalid url")
        }
        XCTAssertNil(invalid.updateURL)

        for channel in [AppDistributionChannel.development, .internal] {
            guard case .force(let prompt) = evaluate(
                minVersion: "2.0",
                updateURL: "https://apps.apple.com/app/id9",
                channel: channel,
                installed: "1.0"
            ).update else {
                return XCTFail(channel.rawValue)
            }
            XCTAssertNil(prompt.updateURL)
            XCTAssertTrue(prompt.usesTesterCopy)
        }
    }

    func testReleaseUpdateURLAllowsOnlyHTTPSAndAppStoreSchemes() {
        let allowed = [
            "https://apps.apple.com/app/id9",
            "HTTPS://apps.apple.com/app/id9",
            "itms-apps://apps.apple.com/app/id9",
            "ITMS-APPS://apps.apple.com/app/id9",
        ]
        for raw in allowed {
            guard case .force(let prompt) = evaluate(
                minVersion: "2.0",
                updateURL: " \(raw) ",
                channel: .release,
                installed: "1.0"
            ).update else {
                return XCTFail(raw)
            }
            XCTAssertEqual(prompt.updateURL?.scheme?.lowercased(), URL(string: raw)?.scheme?.lowercased(), raw)
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
            guard case .force(let prompt) = evaluate(
                minVersion: "2.0",
                updateURL: raw,
                channel: .release,
                installed: "1.0"
            ).update else {
                return XCTFail(raw)
            }
            XCTAssertNil(prompt.updateURL, raw)
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
        XCTAssertNil(blocking.update)
        XCTAssertNil(blocking.banner)

        let force = evaluate(values: floorsAndBanner, installed: "1.0", blocking: false)
        guard case .force = force.update else { return XCTFail("force") }
        XCTAssertNil(force.banner)
        XCTAssertNil(force.blocking)

        var softValues = floorsAndBanner
        softValues[RemoteConfigKey.minVersionIOS] = ""
        let soft = evaluate(values: softValues, installed: "1.0")
        guard case .soft = soft.update else { return XCTFail("soft") }
        XCTAssertEqual(soft.banner?.message, "Tonight")
        XCTAssertNil(soft.blocking)

        let banner = evaluate(
            values: [
                RemoteConfigKey.maintenanceBannerMessage: #"{"en":"Tonight"}"#,
            ],
            installed: "1.0"
        )
        XCTAssertNil(banner.update)
        XCTAssertEqual(banner.banner?.message, "Tonight")

        XCTAssertEqual(evaluate(installed: "1.0").blocking, nil)
        XCTAssertNil(evaluate(installed: "1.0").update)
        XCTAssertNil(evaluate(installed: "1.0").banner)
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
        XCTAssertNil(decision.blocking)
        XCTAssertNil(decision.update)
        XCTAssertNil(decision.banner)
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
            RemoteConfigCopy.laterButton: [
                "en": "Later",
                "sk": "Neskôr",
                "hu": "Később",
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
