import CoreNetworking
import CoreNetworkingTestUtilities
import Foundation
import UIKit
import XCTest
@testable import FeatureHome

final class HomeCatalogTests: XCTestCase {
    private let notificationIDs = [
        "today-first-scan-june-12",
        "today-new-product-june-11",
        "history-first-scan-june-12",
        "history-new-product-june-11-1",
        "history-new-product-june-11-2",
    ]

    func testHomeAndNotificationsDecodeAndMatchCountsInEnglishHungarianAndSlovak() throws {
        let home = try JSONDecoder().decode(HomeDocument.self, from: ContractFixtures.bytes("home.json"))
        let notifications = try JSONDecoder().decode(
            HomeNotificationsPage.self,
            from: ContractFixtures.bytes("notifications.json")
        )
        XCTAssertNil(notifications.nextCursor)
        XCTAssertEqual(notifications.banner.id, "3")
        XCTAssertEqual(notifications.items.map(\.id), notificationIDs)
        XCTAssertEqual(home.notifications.items.map(\.id), notificationIDs)

        let catalog = HomeCatalogMapper.catalog(home)
        XCTAssertEqual(catalog.loyalty.points, 3210)
        XCTAssertEqual(catalog.loyalty.tierId, "silver")
        XCTAssertEqual(catalog.loyalty.progress, home.loyalty.progress)
        XCTAssertEqual(catalog.currentTier.pointsToNext, 290)
        XCTAssertEqual(catalog.currentTier.progress, home.currentTier.progress)
        XCTAssertEqual(catalog.dailyOfferInitialIndex, 1)
        XCTAssertEqual(HomeHeaderMetrics.iconSize, 40)

        let titles = [
            "en": "Buy 1 get 2 Croissants",
            "hu": "Vegyél 1 kapj 2 croissant-t",
            "sk": "Kúp 1 získaj 2 croissanty",
        ]
        let labels = ["en": "Bread", "hu": "Kenyerek", "sk": "Chleby"]
        let offerTitles = [
            "en": "15% Off on every coffee",
            "hu": "15% kedvezmény minden kávéra",
            "sk": "15% zľava na každú kávu",
        ]

        for (language, title) in titles {
            let locale = Locale(identifier: language)
            XCTAssertEqual(catalog.banners.count, 3, language)
            XCTAssertEqual(catalog.bannerItems(locale: locale).count, 3, language)
            XCTAssertEqual(catalog.bannerItems(locale: locale).map(\.id), [0, 1, 2], language)
            XCTAssertNotNil(catalog.notificationBannerItem(locale: locale), language)
            XCTAssertEqual(catalog.notificationBannerItem(locale: locale)?.id, 3, language)
            XCTAssertEqual(catalog.banners.count + 1, 4, language)
            XCTAssertEqual(catalog.products.count, 10, language)
            XCTAssertEqual(catalog.productItems(locale: locale).count, 10, language)
            XCTAssertEqual(catalog.challenges.count, 4, language)
            XCTAssertEqual(catalog.news.count, 2, language)
            XCTAssertEqual(catalog.notificationItems.map(\.id), notificationIDs, language)
            XCTAssertEqual(catalog.todayItems.map(\.id), Array(notificationIDs.prefix(2)), language)
            XCTAssertEqual(catalog.historyItems.map(\.id), Array(notificationIDs.suffix(3)), language)
            XCTAssertEqual(catalog.banners[0].plainTitle(locale: locale), title, language)
            XCTAssertEqual(catalog.products[0].label.resolved(locale: locale), labels[language], language)
            XCTAssertEqual(catalog.notificationBanner.plainTitle(locale: locale), offerTitles[language], language)
            let face = HomeLoyaltyCopy.loyaltyCard(
                loyalty: catalog.loyalty,
                currentTier: catalog.currentTier,
                tiers: catalog.tiers,
                locale: locale
            )
            XCTAssertEqual(face, HomeFirebaseSample.face(locale: locale), language)
            for id in catalog.sectionIDs {
                XCTAssertEqual(
                    catalog.sectionTitle(id, locale: locale),
                    HomeLoyaltyCopy.sectionTitle(id, locale: locale),
                    "\(language) \(id)"
                )
                XCTAssertFalse(catalog.sectionTitle(id, locale: locale).isEmpty, "\(language) \(id)")
            }
        }

        guard case .text(let label) = catalog.products[0].label else {
            return XCTFail("HTTP catalog keeps the localized object")
        }
        XCTAssertEqual(label.en, "Bread")
        XCTAssertEqual(label.sk, "Chleby")
        XCTAssertEqual(label.hu, "Kenyerek")
    }

    func testMissingTranslationFallsBackToEnglish() throws {
        let text = try JSONDecoder().decode(
            HomeLocalizedText.self,
            from: Data(#"{"en":"Silver","sk":"Striebro"}"#.utf8)
        )
        XCTAssertNil(text.hu)
        XCTAssertEqual(text.resolved(locale: Locale(identifier: "hu")), "Silver")
        XCTAssertEqual(text.resolved(locale: Locale(identifier: "sk")), "Striebro")
        XCTAssertEqual(text.resolved(locale: Locale(identifier: "fr")), "Silver")
    }

    func testOmittedChallengeRingDefaultsToOneAndZero() throws {
        let challenge = try JSONDecoder().decode(
            HomeChallengeDTO.self,
            from: Data(#"{"id":"9","iconKey":"croissant","points":1,"title":{"en":"A"}}"#.utf8)
        )
        XCTAssertEqual(challenge.repeatCount, 1)
        XCTAssertEqual(challenge.progress, 0)
        XCTAssertNil(challenge.backgroundToken)
    }

    func testUnknownImageIsOmittedAndUnknownFillIconAndSectionAreDropped() throws {
        let home = try ContractFixtures.text("home.json")
        let teal = replacingFirst(
            #"{"id":"0","backgroundToken":"pink""#,
            with: #"{"id":"0","backgroundToken":"teal""#,
            in: home
        )
        let unknownFill = HomeCatalogMapper.catalog(try decode(teal))
        XCTAssertEqual(unknownFill.banners.count, 2)
        XCTAssertEqual(unknownFill.banners.first?.id, "1")
        XCTAssertEqual(unknownFill.banners.first?.fill, .brown)

        let missingImage = replacingFirst(
            #""imageKey":"home/pastry-1.png""#,
            with: #""imageKey":"home/missing.png""#,
            in: home
        )
        let omittedImage = HomeCatalogMapper.catalog(try decode(missingImage))
        XCTAssertEqual(omittedImage.banners.count, 3)
        XCTAssertNil(omittedImage.banners[1].image)
        XCTAssertEqual(omittedImage.banners[1].id, "1")

        let missingProduct = replacingFirst(
            #""imageKey":"home/pastry-5.png""#,
            with: #""imageKey":"home/missing.png""#,
            in: home
        )
        let omittedProduct = HomeCatalogMapper.catalog(try decode(missingProduct))
        XCTAssertEqual(omittedProduct.products.count, 9)
        XCTAssertEqual(omittedProduct.products.first?.id, "1")

        let missingIcon = replacingFirst(
            #""iconKey":"qrScanLine""#,
            with: #""iconKey":"not-an-icon""#,
            in: home
        )
        let omittedIcon = HomeCatalogMapper.catalog(try decode(missingIcon))
        XCTAssertEqual(omittedIcon.challenges.count, 3)
        XCTAssertEqual(omittedIcon.challenges.first?.id, "1")

        let missingStyle = replacingFirst(
            #""style":"inverse""#,
            with: #""style":"nope""#,
            in: home
        )
        let omittedStyle = HomeCatalogMapper.catalog(try decode(missingStyle))
        XCTAssertEqual(
            omittedStyle.banners[0].plainTitle(locale: Locale(identifier: "en")),
            "1 get 2 Croissants"
        )

        let missingSection = replacingFirst(
            #""id":"today-first-scan-june-12","section":"today""#,
            with: #""id":"today-first-scan-june-12","section":"later""#,
            in: home
        )
        let omittedSection = HomeCatalogMapper.catalog(try decode(missingSection))
        XCTAssertEqual(omittedSection.todayItems.map(\.id), ["today-new-product-june-11"])

        var withoutProducts = HomeCatalogMapper.catalog(try decode(home))
        withoutProducts.sectionIDs.removeAll { $0 == "products" }
        XCTAssertEqual(withoutProducts.sectionTitle("products", locale: Locale(identifier: "en")), "")
        XCTAssertEqual(withoutProducts.products.count, 10)

        let banner = HomeBanner(
            id: "not-a-number",
            fill: .pink,
            badge: .text(HomeLocalizedText(en: "A")),
            titleRuns: [],
            image: nil
        )
        XCTAssertNil(banner.carouselItem(locale: Locale(identifier: "en")))
    }

    func testFirebaseSampleKeepsKeysAndMatchesTheMappedEnglishCatalog() throws {
        let sample = HomeCatalog.firebase
        guard case .key(let key) = sample.products[0].label else {
            return XCTFail("firebase sample keeps the xcstrings key")
        }
        XCTAssertEqual(key, "home.products.category.bread")
        XCTAssertEqual(sample.notificationItems.map(\.id), notificationIDs)
        XCTAssertNil(sample.banners[0].image)
        XCTAssertEqual(sample.banners[1].image, .pastry1)

        let remote = HomeCatalogMapper.catalog(try homeDocument())
        let english = Locale(identifier: "en")
        XCTAssertEqual(
            remote.banners.map { $0.plainTitle(locale: english) },
            sample.banners.map { $0.plainTitle(locale: english) }
        )
        XCTAssertEqual(remote.banners.map(\.fill), sample.banners.map(\.fill))
        XCTAssertEqual(remote.banners.map(\.image), sample.banners.map(\.image))
        XCTAssertEqual(
            remote.products.map { $0.label.resolved(locale: english) },
            sample.products.map { $0.label.resolved(locale: english) }
        )
        XCTAssertEqual(remote.products.map(\.showDiscount), sample.products.map(\.showDiscount))
        XCTAssertEqual(remote.products.map(\.image), sample.products.map(\.image))
        XCTAssertEqual(
            remote.challenges.map(\.points),
            sample.challenges.map(\.points)
        )
        XCTAssertEqual(
            remote.challengeItems(locale: english).map(\.badgeText),
            ["+45 pts", "+45 pts", "+25 pts", "+45 pts"]
        )
        XCTAssertEqual(remote.news.map(\.image), sample.news.map(\.image))
        XCTAssertEqual(remote.notificationItems.map(\.id), sample.notificationItems.map(\.id))
        XCTAssertEqual(remote.notificationItems.map(\.points), sample.notificationItems.map(\.points))
        let face = HomeLoyaltyCopy.loyaltyCard(
            loyalty: sample.loyalty,
            currentTier: sample.currentTier,
            tiers: sample.tiers,
            locale: english
        )
        XCTAssertEqual(face, HomeFirebaseSample.face(locale: english))
    }

    func testHTTPRepositoryGetsV1HomeAndFirebaseDoesNot() async throws {
        let document = try homeDocument()
        let client = RecordingHomeClient(result: .success(document))
        let catalog = try await HttpHomeRepository(client: client).load()
        XCTAssertEqual(client.paths, [HttpHomeRepository.path])
        XCTAssertEqual(HttpHomeRepository.path, "/v1/home")
        XCTAssertEqual(client.methods, [.GET])
        XCTAssertTrue(client.dataURLs.isEmpty)
        XCTAssertEqual(catalog.banners.count, 3)
        XCTAssertNil(catalog.banners[0].image)
        XCTAssertEqual(catalog.products.count, 10)

        let idle = RecordingHomeClient(result: .failure(NetworkError.invalidURL))
        let firebase = try await FirebaseHomeRepository().load()
        XCTAssertEqual(firebase, .firebase)
        XCTAssertTrue(idle.paths.isEmpty)
        XCTAssertTrue(idle.dataURLs.isEmpty)

        let selected = HomeRepositoryFactory.make(dataBackend: " http ", networkClient: client)
        _ = try await selected.load()
        XCTAssertEqual(client.paths, ["/v1/home", "/v1/home"])

        let sampleClient = RecordingHomeClient(result: .failure(NetworkError.invalidURL))
        let sample = HomeRepositoryFactory.make(dataBackend: " firebase ", networkClient: sampleClient)
        let loaded = try await sample.load()
        XCTAssertEqual(loaded, .firebase)
        XCTAssertTrue(sampleClient.paths.isEmpty)
    }

    func testAvatarRequestSkipsNilEmptyAndForeignHosts() async {
        let api = "https://api.zappte.eu/mock/min"
        let client = RecordingHomeClient(result: .failure(NetworkError.invalidURL))
        let skipped = [
            nil,
            "",
            "   ",
            "file:///tmp/avatar.webp",
            "https://cdn.example/v1/media/avatars/default.webp",
            "http://127.0.0.1:8080/v1/media/avatars/default.webp",
            "http://api.zappte.eu/v1/media/avatars/default.webp",
        ]
        for avatarURL in skipped {
            let image = await AvatarImageLoader.load(avatarURL: avatarURL, apiBaseURL: api, client: client)
            XCTAssertNil(image, avatarURL ?? "nil")
        }
        XCTAssertTrue(client.dataURLs.isEmpty)

        let match = AvatarRequestURL.resolved(
            avatarURL: "https://api.zappte.eu/v1/media/avatars/default.webp",
            apiBaseURL: api
        )
        XCTAssertEqual(match?.host, "api.zappte.eu")
        let explicitPort = AvatarRequestURL.resolved(
            avatarURL: "https://api.minit.app:8443/v1/media/avatars/default.webp",
            apiBaseURL: "https://api.minit.app"
        )
        XCTAssertNil(explicitPort)
    }

    func testAvatarLoadDecodesBytesAndDropsHTTPAndDecodeErrors() async {
        let url = "https://api.minit.app/v1/media/avatars/default.webp"
        let base = "https://api.minit.app"
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!
        let success = RecordingHomeClient(result: .success(try! homeDocument()), data: png)
        let image = await AvatarImageLoader.load(avatarURL: url, apiBaseURL: base, client: success)
        XCTAssertNotNil(image)
        XCTAssertEqual(success.dataURLs.map(\.absoluteString), [url])

        let garbage = RecordingHomeClient(result: .success(try! homeDocument()), data: Data("nope".utf8))
        let undecoded = await AvatarImageLoader.load(avatarURL: url, apiBaseURL: base, client: garbage)
        XCTAssertNil(undecoded)
        XCTAssertEqual(garbage.dataURLs.count, 1)

        let failed = RecordingHomeClient(result: .failure(NetworkError.statusCode(404, Data())))
        let missing = await AvatarImageLoader.load(avatarURL: url, apiBaseURL: base, client: failed)
        XCTAssertNil(missing)
        XCTAssertEqual(failed.dataURLs.count, 1)
    }

    private func homeDocument() throws -> HomeDocument {
        try JSONDecoder().decode(HomeDocument.self, from: ContractFixtures.bytes("home.json"))
    }

    private func decode(_ text: String) throws -> HomeDocument {
        try JSONDecoder().decode(HomeDocument.self, from: Data(text.utf8))
    }

    private func replacingFirst(_ target: String, with replacement: String, in text: String) -> String {
        guard let range = text.range(of: target) else {
            XCTFail("missing \(target)")
            return text
        }
        var copy = text
        copy.replaceSubrange(range, with: replacement)
        return copy
    }
}

private enum ScriptedBody {
    case success(HomeDocument)
    case failure(Error)
}

private final class RecordingHomeClient: NetworkClient, @unchecked Sendable {
    private let result: ScriptedBody
    private let data: Data
    private(set) var paths: [String] = []
    private(set) var methods: [HTTPMethod] = []
    private(set) var dataURLs: [URL] = []

    init(result: ScriptedBody, data: Data = Data()) {
        self.result = result
        self.data = data
    }

    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        paths.append(path)
        methods.append(method)
        switch result {
        case .failure(let error):
            throw error
        case .success(let document):
            guard let typed = document as? T else { throw NetworkError.invalidResponse }
            return typed
        }
    }

    func request<T: Decodable, B: Encodable>(
        _ path: String,
        method: HTTPMethod,
        body: B
    ) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ url: URL) async throws -> Data {
        dataURLs.append(url)
        switch result {
        case .failure(let error):
            throw error
        case .success:
            return data
        }
    }
}
