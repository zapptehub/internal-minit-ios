import CoreNetworkingTestUtilities
import Foundation
import XCTest
@testable import FeatureHome

final class HomeLoyaltyCopyTests: XCTestCase {
    func testFirebaseSampleMatchesTheHomeFixture() throws {
        let home = try homeSlice()
        XCTAssertEqual(HomeFirebaseSample.loyalty.points, home.loyalty.points)
        XCTAssertEqual(HomeFirebaseSample.loyalty.tierId, home.loyalty.tierId)
        XCTAssertEqual(HomeFirebaseSample.loyalty.progress, home.loyalty.progress)
        XCTAssertEqual(HomeFirebaseSample.currentTier.id, home.currentTier.id)
        XCTAssertEqual(HomeFirebaseSample.currentTier.pointsToNext, home.currentTier.pointsToNext)
        XCTAssertEqual(HomeFirebaseSample.currentTier.progress, home.currentTier.progress)
        XCTAssertEqual(HomeFirebaseSample.tiers.map(\.id), home.tiers.map(\.id))
        XCTAssertEqual(HomeFirebaseSample.tiers.map(\.floor), home.tiers.map(\.floor))
        XCTAssertEqual(HomeFirebaseSample.tiers.map(\.nextFloor), home.tiers.map(\.nextFloor))

        let formatted = HomeLoyaltyCopy.loyaltyCard(
            loyalty: HomeLoyaltyNumbers(
                points: home.loyalty.points,
                tierId: home.loyalty.tierId,
                progress: home.loyalty.progress
            ),
            currentTier: HomeCurrentTierNumbers(
                id: home.currentTier.id,
                pointsToNext: home.currentTier.pointsToNext,
                progress: home.currentTier.progress
            ),
            tiers: home.tiers.map {
                HomeLoyaltyRung(id: $0.id, floor: $0.floor, nextFloor: $0.nextFloor)
            },
            locale: Locale(identifier: "en")
        )
        XCTAssertEqual(formatted, HomeFirebaseSample.face(locale: Locale(identifier: "en")))
    }

    func testUnreadableFirebaseSampleRendersANeutralFace() throws {
        let missingRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("home-sample-missing-\(UUID().uuidString)", isDirectory: true)
        let brokenRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("home-sample-broken-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: missingRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: brokenRoot, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: missingRoot)
            try? FileManager.default.removeItem(at: brokenRoot)
        }
        try Data("{".utf8).write(to: brokenRoot.appendingPathComponent("HomeFirebaseSample.json"))

        let english = Locale(identifier: "en")
        let missingBundle = try XCTUnwrap(Bundle(path: missingRoot.path))
        let brokenBundle = try XCTUnwrap(Bundle(path: brokenRoot.path))
        let missing = HomeFirebaseSample.face(locale: english, bundle: missingBundle)
        let broken = HomeFirebaseSample.face(locale: english, bundle: brokenBundle)

        XCTAssertEqual(missing.points, 0)
        XCTAssertEqual(missing.rankProgress, 0)
        XCTAssertEqual(missing.rankTitle, "Tier")
        XCTAssertEqual(missing.rankSubtitle, "Top tier")
        XCTAssertEqual(missing.chipLabel, "Minit Card")
        XCTAssertEqual(broken, missing)
        XCTAssertNotEqual(missing, HomeFirebaseSample.face(locale: english))
    }

    func test3210FaceInEnglishHungarianAndSlovak() {
        let cases: [(String, String, String, String)] = [
            ("en", "Silver", "290 pts until Gold", "Minit Card"),
            ("hu", "Ezüst", "290 pont az Aranyig", "Minit kártya"),
            ("sk", "Striebro", "290 bodov do Zlata", "Minit karta"),
        ]
        for (language, title, subtitle, chip) in cases {
            let face = HomeFirebaseSample.face(locale: Locale(identifier: language))
            XCTAssertEqual(face.rankTitle, title, language)
            XCTAssertEqual(face.rankSubtitle, subtitle, language)
            XCTAssertEqual(face.chipLabel, chip, language)
            XCTAssertEqual(face.points, 3210, language)
            XCTAssertEqual(face.rankProgress, HomeFirebaseSample.loyalty.progress, language)
        }
    }

    func testProgressIsTheSuppliedToken() {
        let face = card(tier: "silver", pointsToNext: 290, progress: 0.25, locale: Locale(identifier: "en"))
        XCTAssertEqual(face.rankProgress, 0.25)
        XCTAssertEqual(face.rankSubtitle, "290 pts until Gold")
    }

    func testPlatinumIsTheTopTierLineAndProgressOne() {
        let cases = [
            ("en", "Platinum", "Top tier"),
            ("hu", "Platina", "Legmagasabb szint"),
            ("sk", "Platina", "Najvyššia úroveň"),
        ]
        for (language, title, subtitle) in cases {
            let face = card(
                tier: "platinum",
                pointsToNext: nil,
                progress: 1,
                locale: Locale(identifier: language)
            )
            XCTAssertEqual(face.rankTitle, title, language)
            XCTAssertEqual(face.rankSubtitle, subtitle, language)
            XCTAssertEqual(face.rankProgress, 1, language)
        }
    }

    func testEnglishAndHungarianPointsPlurals() {
        let english = Locale(identifier: "en")
        let hungarian = Locale(identifier: "hu")
        XCTAssertEqual(HomeLoyaltyCopy.pointsBadge(1, locale: english), "+1 pt")
        XCTAssertEqual(HomeLoyaltyCopy.pointsBadge(45, locale: english), "+45 pts")
        XCTAssertEqual(card(tier: "gold", pointsToNext: 1, locale: english).rankSubtitle, "1 pt until Platinum")
        XCTAssertEqual(card(tier: "gold", pointsToNext: 2, locale: english).rankSubtitle, "2 pts until Platinum")
        XCTAssertEqual(HomeLoyaltyCopy.pointsBadge(1, locale: hungarian), "+1 pont")
        XCTAssertEqual(HomeLoyaltyCopy.pointsBadge(4, locale: hungarian), "+4 pont")
        XCTAssertEqual(card(tier: "bronze", pointsToNext: 1, locale: hungarian).rankSubtitle, "1 pont az Ezüstig")
        XCTAssertEqual(card(tier: "gold", pointsToNext: 4, locale: hungarian).rankSubtitle, "4 pont a Platináig")
    }

    /// The formatted string is the catalog plural for that language and category,
    /// including Slovak `few`, not the raw `%#@` token and not another category
    /// when that category has its own wording.
    func testPluralVariantsComeFromTheCatalogTableForEnglishHungarianAndSlovak() throws {
        let table = try catalogPluralTable()
        for key in [
            "home.notifications.pointsFormat",
            "home.loyalty.pointsUntil.silver",
            "home.loyalty.pointsUntil.gold",
            "home.loyalty.pointsUntil.platinum",
            "home.loyalty.pointsUntil.next",
        ] {
            XCTAssertNotNil(table[key], key)
        }

        let samples: [(String, Int, String)] = [
            ("en", 1, "one"),
            ("en", 5, "other"),
            ("hu", 1, "one"),
            ("hu", 4, "other"),
            ("sk", 1, "one"),
            ("sk", 2, "few"),
            ("sk", 4, "few"),
            ("sk", 5, "other"),
            ("sk", 21, "other"),
        ]
        var distinguishedCategory = false
        for (key, languages) in table {
            for (language, count, category) in samples {
                let forms = try XCTUnwrap(languages[language], "\(key) \(language)")
                let variant = try XCTUnwrap(forms[category], "\(key) \(language) \(category)")
                let other = try XCTUnwrap(forms["other"], "\(key) \(language) other")
                XCTAssertFalse(variant.contains("%#@"), "\(key) \(language) \(category)")
                let locale = Locale(identifier: language)
                let actual = HomeLocalizedString.quantity(key, count, locale: locale)
                XCTAssertEqual(
                    actual,
                    String(format: variant, locale: locale, count),
                    "\(key) \(language) \(count) \(category)"
                )
                XCTAssertFalse(actual.contains("%#@"), "\(key) \(language) \(count)")
                if variant != other {
                    distinguishedCategory = true
                    XCTAssertNotEqual(
                        actual,
                        String(format: other, locale: locale, count),
                        "\(key) \(language) \(count) fell back to other"
                    )
                }
            }
        }
        XCTAssertTrue(distinguishedCategory)
    }

    func testMissingPluralCategoryUsesOtherAndATokenIsNeverShown() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("home-plurals-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("en.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let plist: [String: Any] = [
            "demo.onlyOther": [
                "NSStringLocalizedFormatKey": "%#@value@",
                "value": [
                    "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                    "NSStringFormatValueTypeKey": "d",
                    "other": "%d other",
                ],
            ],
            "demo.tokenOne": [
                "NSStringLocalizedFormatKey": "%#@value@",
                "value": [
                    "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                    "NSStringFormatValueTypeKey": "d",
                    "one": "%#@value@",
                    "other": "%d safe",
                ],
            ],
            "demo.token": [
                "NSStringLocalizedFormatKey": "%#@value@",
                "value": [
                    "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                    "NSStringFormatValueTypeKey": "d",
                    "one": "%#@value@",
                    "other": "%#@value@",
                ],
            ],
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: lproj.appendingPathComponent("Localizable.stringsdict"))
        let bundle = try XCTUnwrap(Bundle(path: root.path))
        let english = Locale(identifier: "en")

        let onlyOther = HomeLocalizedString.quantity("demo.onlyOther", 1, locale: english, bundle: bundle)
        XCTAssertEqual(onlyOther, "1 other")
        XCTAssertFalse(onlyOther.contains("%#@"))

        let tokenOne = HomeLocalizedString.quantity("demo.tokenOne", 1, locale: english, bundle: bundle)
        XCTAssertEqual(tokenOne, "1 safe")
        XCTAssertFalse(tokenOne.contains("%#@"))

        let token = HomeLocalizedString.quantity("demo.token", 2, locale: english, bundle: bundle)
        XCTAssertEqual(token, "2")
        XCTAssertFalse(token.contains("%#@"))

        let missing = HomeLocalizedString.quantity("no.such.key", 3, locale: english, bundle: bundle)
        XCTAssertFalse(missing.contains("%#@"))
    }

    /// In-app Slovak locale: `one` / `few` / `other`, including 21, for until-gold,
    /// the badge, and until-next.
    ///
    /// This does not change the process language. The failure message records
    /// `Locale.current`. A helper that started reading `Locale.current` would
    /// still pass when that process language was already Slovak.
    func testSlovakPluralsFollowThePassedLocaleIncluding21() {
        let slovak = Locale(identifier: "sk")
        let process = Locale.current.language.languageCode?.identifier ?? ""
        let untilGold = [
            1: "1 bod do Zlata",
            2: "2 body do Zlata",
            4: "4 body do Zlata",
            5: "5 bodov do Zlata",
            21: "21 bodov do Zlata",
        ]
        let badges = [
            1: "+1 bod",
            2: "+2 body",
            4: "+4 body",
            5: "+5 bodov",
            21: "+21 bodov",
        ]
        let untilNext = [
            1: "1 bod do ďalšej úrovne",
            2: "2 body do ďalšej úrovne",
            4: "4 body do ďalšej úrovne",
            5: "5 bodov do ďalšej úrovne",
            21: "21 bodov do ďalšej úrovne",
        ]
        for count in [1, 2, 4, 5, 21] {
            XCTAssertEqual(
                card(tier: "silver", pointsToNext: count, locale: slovak).rankSubtitle,
                untilGold[count],
                "until gold \(count) process \(process)"
            )
            XCTAssertEqual(
                HomeLoyaltyCopy.pointsBadge(count, locale: slovak),
                badges[count],
                "badge \(count) process \(process)"
            )
            XCTAssertEqual(
                untilNextTier(pointsToNext: count, locale: slovak),
                untilNext[count],
                "next \(count) process \(process)"
            )
        }
        XCTAssertNotEqual(
            HomeLoyaltyCopy.pointsBadge(2, locale: slovak),
            HomeLoyaltyCopy.pointsBadge(2, locale: Locale(identifier: "en"))
        )
    }

    func testUnknownTierUsesANeutralNameAndUnknownNextRungUsesTheNextTierLine() {
        let english = Locale(identifier: "en")
        let diamondToPlatinum = [
            HomeLoyaltyRung(id: "diamond", floor: 10, nextFloor: 20),
            HomeLoyaltyRung(id: "platinum", floor: 20, nextFloor: nil),
        ]
        let unknownCurrent = HomeLoyaltyCopy.loyaltyCard(
            loyalty: HomeLoyaltyNumbers(points: 15, tierId: "diamond", progress: 0.5),
            currentTier: HomeCurrentTierNumbers(id: "diamond", pointsToNext: 5, progress: 0.5),
            tiers: diamondToPlatinum,
            locale: english
        )
        XCTAssertEqual(unknownCurrent.rankTitle, "Tier")
        XCTAssertEqual(unknownCurrent.rankSubtitle, "5 pts until Platinum")
        XCTAssertFalse(unknownCurrent.rankTitle.contains("diamond"))

        let bronzeToDiamond = [
            HomeLoyaltyRung(id: "bronze", floor: 10, nextFloor: 20),
            HomeLoyaltyRung(id: "diamond", floor: 20, nextFloor: nil),
        ]
        let unknownNext = HomeLoyaltyCopy.loyaltyCard(
            loyalty: HomeLoyaltyNumbers(points: 12, tierId: "bronze", progress: 0.4),
            currentTier: HomeCurrentTierNumbers(id: "bronze", pointsToNext: 8, progress: 0.4),
            tiers: bronzeToDiamond,
            locale: english
        )
        XCTAssertEqual(unknownNext.rankTitle, "Bronze")
        XCTAssertEqual(unknownNext.rankSubtitle, "8 pts until the next tier")
        XCTAssertFalse(unknownNext.rankSubtitle.contains("Top tier"))
        XCTAssertFalse(unknownNext.rankSubtitle.contains("diamond"))
        XCTAssertFalse(unknownNext.rankSubtitle.contains("Platinum"))

        let bothUnknown = HomeLoyaltyCopy.loyaltyCard(
            loyalty: HomeLoyaltyNumbers(points: 12, tierId: "diamond", progress: 0.4),
            currentTier: HomeCurrentTierNumbers(id: "diamond", pointsToNext: 8, progress: 0.4),
            tiers: bronzeToDiamond,
            locale: english
        )
        XCTAssertEqual(bothUnknown.rankTitle, "Tier")
        XCTAssertEqual(bothUnknown.rankSubtitle, "8 pts until the next tier")

        let unknownTop = HomeLoyaltyCopy.loyaltyCard(
            loyalty: HomeLoyaltyNumbers(points: 30, tierId: "diamond", progress: 1),
            currentTier: HomeCurrentTierNumbers(id: "diamond", pointsToNext: nil, progress: 1),
            tiers: [HomeLoyaltyRung(id: "diamond", floor: 10, nextFloor: nil)],
            locale: english
        )
        XCTAssertEqual(unknownTop.rankTitle, "Tier")
        XCTAssertEqual(unknownTop.rankSubtitle, "Top tier")
        XCTAssertEqual(unknownTop.rankProgress, 1)

        XCTAssertEqual(neutralTitle(locale: Locale(identifier: "sk")), "Úroveň")
        XCTAssertEqual(neutralTitle(locale: Locale(identifier: "hu")), "Szint")
        XCTAssertEqual(untilNextTier(pointsToNext: 1, locale: english), "1 pt until the next tier")
        XCTAssertEqual(untilNextTier(pointsToNext: 2, locale: english), "2 pts until the next tier")
        XCTAssertEqual(untilNextTier(pointsToNext: 1, locale: Locale(identifier: "hu")), "1 pont a következő szintig")
    }

    func testSectionTitlesUseTheExistingKeys() {
        let keys = [
            "products": "home.products.title",
            "challenges": "home.challenges.title",
            "news": "home.newsAndRecipes.title",
            "notifications": "home.notifications.title",
            "today": "home.notifications.section.today",
            "history": "home.notifications.section.allHistory",
        ]
        for language in ["en", "hu", "sk"] {
            let locale = Locale(identifier: language)
            for (id, key) in keys {
                let title = HomeLoyaltyCopy.sectionTitle(id, locale: locale)
                XCTAssertEqual(title, HomeLocalizedString.string(key, locale: locale), "\(language) \(id)")
                XCTAssertFalse(title.isEmpty, "\(language) \(id)")
            }
            XCTAssertEqual(HomeLoyaltyCopy.sectionTitle("offers", locale: locale), "", language)
        }
    }

    func testOldRankStringsAreGoneFromHome() throws {
        let root = repositoryRoot()
        let catalog = try String(
            contentsOf: root.appendingPathComponent("Feature-Home/Sources/FeatureHome/Resources/Localizable.xcstrings"),
            encoding: .utf8
        )
        XCTAssertFalse(catalog.contains("540"))
        XCTAssertFalse(catalog.contains("home.loyaltyCard.rankTitle"))
        XCTAssertFalse(catalog.contains("home.loyaltyCard.rankSubtitle"))

        let home = try String(
            contentsOf: root.appendingPathComponent("Feature-Home/Sources/FeatureHome/UI/HomeScreen.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(home.contains("3210"))
        XCTAssertFalse(home.contains("540"))
        XCTAssertFalse(home.contains("home.loyaltyCard.rankTitle"))
        XCTAssertFalse(home.contains("home.loyaltyCard.rankSubtitle"))

        let card = try String(
            contentsOf: root.appendingPathComponent("Core-DesignSystem/Sources/DesignSystem/Components/LoyaltyCard.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(card.contains("0.75"))
        XCTAssertFalse(card.contains("3210"))
        XCTAssertFalse(card.contains("540"))
        XCTAssertFalse(card.contains("\"Silver\""))
    }

    func testFloorValuesStayInTheFirebaseSampleAndHomeJson() throws {
        let root = repositoryRoot()
        let pattern = #"(?:^|[^A-Za-z0-9_.])(?:1500|3500|6000|1_500|3_500|6_000)(?![A-Za-z0-9_])"#
        let regex = try NSRegularExpression(pattern: pattern)
        let allowed: Set<String> = [
            "Feature-Home/Sources/FeatureHome/Resources/HomeFirebaseSample.json",
            "Core-Networking/Sources/CoreNetworkingTestUtilities/Resources/contract/home.json",
        ]
        for relative in allowed {
            let text = try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            XCTAssertNotNil(regex.firstMatch(in: text, range: range), relative)
        }

        var hits: [String] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            XCTFail("could not read \(root.path)")
            return
        }
        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent
            if name == "DerivedData" || name == "SourcePackages" || name == "checkouts" || name == ".build" {
                enumerator.skipDescendants()
                continue
            }
            let relative = relativePath(url, root: root)
            guard relative.contains("/Sources/") || relative.hasPrefix("Sources/") else { continue }
            let ext = url.pathExtension
            guard ext == "swift" || ext == "json" || ext == "xcstrings" else { continue }
            if allowed.contains(relative) { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(text.startIndex..., in: text)
            if regex.firstMatch(in: text, range: range) != nil {
                hits.append(relative)
            }
        }
        XCTAssertEqual(hits, [])
    }

    private func card(
        tier: String,
        pointsToNext: Int?,
        progress: Double = 0.86,
        locale: Locale
    ) -> HomeLoyaltyFace {
        HomeLoyaltyCopy.loyaltyCard(
            loyalty: HomeLoyaltyNumbers(points: 3210, tierId: tier, progress: progress),
            currentTier: HomeCurrentTierNumbers(id: tier, pointsToNext: pointsToNext, progress: progress),
            tiers: HomeFirebaseSample.tiers,
            locale: locale
        )
    }

    private func untilNextTier(pointsToNext: Int, locale: Locale) -> String {
        HomeLoyaltyCopy.loyaltyCard(
            loyalty: HomeLoyaltyNumbers(points: pointsToNext, tierId: "bronze", progress: 0.4),
            currentTier: HomeCurrentTierNumbers(id: "bronze", pointsToNext: pointsToNext, progress: 0.4),
            tiers: [
                HomeLoyaltyRung(id: "bronze", floor: 10, nextFloor: 20),
                HomeLoyaltyRung(id: "diamond", floor: 20, nextFloor: nil),
            ],
            locale: locale
        ).rankSubtitle
    }

    private func neutralTitle(locale: Locale) -> String {
        HomeLoyaltyCopy.loyaltyCard(
            loyalty: HomeLoyaltyNumbers(points: 12, tierId: "diamond", progress: 0.4),
            currentTier: HomeCurrentTierNumbers(id: "diamond", pointsToNext: 8, progress: 0.4),
            tiers: [
                HomeLoyaltyRung(id: "bronze", floor: 10, nextFloor: 20),
                HomeLoyaltyRung(id: "diamond", floor: 20, nextFloor: nil),
            ],
            locale: locale
        ).rankTitle
    }

    private struct HomeSlice: Decodable {
        struct Loyalty: Decodable {
            let points: Int
            let tierId: String
            let progress: Double
        }

        struct Tier: Decodable {
            let id: String
            let floor: Int
            let nextFloor: Int?
        }

        struct CurrentTier: Decodable {
            let id: String
            let pointsToNext: Int?
            let progress: Double
        }

        let loyalty: Loyalty
        let tiers: [Tier]
        let currentTier: CurrentTier
    }

    private func homeSlice() throws -> HomeSlice {
        try JSONDecoder().decode(HomeSlice.self, from: ContractFixtures.bytes("home.json"))
    }

    /// key → language → plural category → format from `Localizable.xcstrings`.
    private func catalogPluralTable() throws -> [String: [String: [String: String]]] {
        let url = repositoryRoot().appendingPathComponent(
            "Feature-Home/Sources/FeatureHome/Resources/Localizable.xcstrings"
        )
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = root?["strings"] as? [String: Any]
        var table: [String: [String: [String: String]]] = [:]
        for (key, rawEntry) in strings ?? [:] {
            guard let entry = rawEntry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any] else { continue }
            var byLanguage: [String: [String: String]] = [:]
            for (language, rawLocalization) in localizations {
                guard let localization = rawLocalization as? [String: Any],
                      let variations = localization["variations"] as? [String: Any],
                      let plural = variations["plural"] as? [String: Any] else { continue }
                var forms: [String: String] = [:]
                for (category, rawForm) in plural {
                    guard let form = rawForm as? [String: Any],
                          let unit = form["stringUnit"] as? [String: Any],
                          let value = unit["value"] as? String else { continue }
                    forms[category] = value
                }
                if !forms.isEmpty {
                    byLanguage[language] = forms
                }
            }
            if !byLanguage.isEmpty {
                table[key] = byLanguage
            }
        }
        return table
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func relativePath(_ url: URL, root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let path = url.path
        if path.hasPrefix(rootPath) {
            return String(path.dropFirst(rootPath.count))
        }
        return path
    }
}
