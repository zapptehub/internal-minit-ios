import CoreNetworking
import DataProfile
import SwiftUI
import UIKit
import XCTest
@testable import FeatureHome

final class FeatureHomeTests: XCTestCase {
    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureHome.createScreen(
            userId: "user-1",
            profileRepository: StubProfileRepository(),
            homeRepository: FirebaseHomeRepository(),
            networkClient: UnusedHomeNetworkClient(),
            apiBaseURL: "https://api.minit.app",
            onLogOut: {}
        )
    }

    /// VoiceOver reads the offer name and the offer title as one label.
    func testNotificationsDailyOfferBannerReadsTheOfferText() {
        let cases: [(String, String, String)] = [
            ("en", "Daily Offer", "15% Off on every coffee"),
            ("hu", "Napi ajánlat", "15% kedvezmény minden kávéra"),
            ("sk", "Denná ponuka", "15% zľava na každú kávu"),
        ]
        for (identifier, name, title) in cases {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(NotificationsScreen.dailyOfferPlainTitle(locale: locale), title, identifier)
            XCTAssertEqual(
                NotificationsScreen.dailyOfferAccessibilityLabel(locale: locale),
                "\(name), \(title)",
                identifier
            )
            XCTAssertNotEqual(
                NotificationsScreen.dailyOfferAccessibilityLabel(locale: locale),
                name,
                identifier
            )
        }
        XCTAssertEqual(
            NotificationsDailyOfferAccessibility.label(offerName: "Daily Offer", offerTitle: " "),
            "Daily Offer"
        )
        XCTAssertEqual(
            NotificationsDailyOfferAccessibility.label(offerName: " ", offerTitle: "15% Off on every coffee"),
            "15% Off on every coffee"
        )
    }

    /// Figma "AMP / Notifications" 4088:1319.
    func testNotificationsBannerHasItsOwnID() {
        // Home's daily offers are 0, 1 and 2; Android's fixture uses 3 too.
        XCTAssertEqual(NotificationsScreen.dailyOfferBannerID, 3)
        XCTAssertEqual(Int(HomeCatalog.firebase.notificationBanner.id), NotificationsScreen.dailyOfferBannerID)
    }

    /// The firebase sample's notification banner is the same sentence the static helper locks.
    func testFirebaseNotificationBannerMatchesTheStaticDailyOfferCopy() {
        for identifier in ["en", "hu", "sk"] {
            let locale = Locale(identifier: identifier)
            XCTAssertEqual(
                HomeCatalog.firebase.notificationBanner.plainTitle(locale: locale),
                NotificationsScreen.dailyOfferPlainTitle(locale: locale),
                identifier
            )
            XCTAssertEqual(
                HomeCatalog.firebase.notificationBanner.badge.resolved(locale: locale),
                HomeLocalizedString.string("home.notifications.a11y.dailyOffer", locale: locale),
                identifier
            )
        }
    }

    func testNotificationsMetricsMatchFigma() {
        typealias M = NotificationsScreenMetrics
        XCTAssertEqual(M.horizontalInset, 20)
        XCTAssertEqual(M.headerTopSpacing, 10)
        XCTAssertEqual(M.backCircleSize, 40)
        XCTAssertEqual(M.backIconSize, 16)
        XCTAssertEqual(M.backBorderWidth, 1)
        XCTAssertGreaterThanOrEqual(M.backTapTargetSize, 44)
        XCTAssertEqual(M.backTapTargetInset, 2)
        XCTAssertEqual(M.backButtonToTitleSpacing, 8 + 16)
        XCTAssertEqual(M.titleToBannerSpacing, 16)
        XCTAssertEqual(M.columnSpacing, 24)
        XCTAssertEqual(M.sectionTitleLineBox, 23)
        XCTAssertEqual(M.sectionTitleToRowsSpacing, 12)
        XCTAssertEqual(M.rowSpacing, 20)
        XCTAssertEqual(M.iconCircleSize, 40)
        XCTAssertEqual(M.iconSize, 24)
        XCTAssertEqual(M.iconToTextSpacing, 12)
        XCTAssertEqual(M.rowLineHeight, 20)
        XCTAssertEqual(M.rowTitlePointSize, 16)
        XCTAssertEqual(M.coinSize, 16)
        XCTAssertEqual(M.coinToPointsSpacing, 8)
        XCTAssertEqual(M.bottomSpacing, 104)
    }

    /// A row is the 40pt circle tall: two 20pt text lines beside it.
    @MainActor
    func testNotificationRowIsFortyTallAtTheDefaultSize() {
        let row = NotificationRow(
            item: HomeNotificationItem(
                id: "today-first-scan-june-12",
                section: .today,
                icon: .baguette,
                title: .key("home.notifications.row.firstScan"),
                date: .key("home.notifications.date.june12"),
                points: 45
            ),
            pointsLabel: "+45 pts"
        )
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.dynamicTypeSize, .large)
        let size = UIHostingController(rootView: row)
            .sizeThatFits(in: CGSize(width: 362, height: CGFloat.greatestFiniteMagnitude))
        XCTAssertEqual(size.height, 40, accuracy: 0.5)
        XCTAssertEqual(size.width, 362, accuracy: 0.5)
    }

    /// The Daily Offer banner's Figma "Small" shadow comes from `DSBannerCarousel` and is
    /// drawn once: grey 240 at 6pt and 248 at 20pt under the banner centre, as in Figma.
    /// A second, screen-drawn copy would make it about twice as dark.
    @MainActor
    func testNotificationsBannerShadowIsDrawnOnce() throws {
        let size = CGSize(width: 402, height: 874)
        let host = UIHostingController(
            rootView: NotificationsScreen(onBack: {})
                .environment(\.locale, Locale(identifier: "en"))
                .environment(\.dynamicTypeSize, .large)
        )
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        host.view.frame = window.bounds
        host.view.backgroundColor = .white
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let width = Int(size.width), height = Int(size.height)
        typealias M = NotificationsScreenMetrics
        // Back button (inset tap area) → title (38pt line box) → banner, with no safe area.
        let bannerTop = (M.headerTopSpacing - M.backTapTargetInset) + M.backTapTargetSize
            + (M.backButtonToTitleSpacing - M.backTapTargetInset) + 38 + M.titleToBannerSpacing
        let bannerBottom = Int(bannerTop) + 80
        func render() -> (fill: Double, background: Double, below6: Double, below20: Double) {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            bytes.withUnsafeMutableBytes { buffer in
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )!
                // `drawHierarchy` draws nothing without a window scene; the layer tree renders,
                // bottom row first in this bitmap (Core Graphics order).
                host.view.layer.render(in: context)
            }
            func grey(_ x: Int, _ y: Int) -> Double {
                let i = ((height - 1 - y) * width + x) * 4
                return (Double(bytes[i]) + Double(bytes[i + 1]) + Double(bytes[i + 2])) / 3
            }
            let background = grey(398, 2)
            return (
                fill: grey(201, bannerBottom - 4),
                background: background,
                below6: background - grey(201, bannerBottom + 6),
                below20: background - grey(201, bannerBottom + 20)
            )
        }
        func shadowIsDrawn(
            _ sample: (fill: Double, background: Double, below6: Double, below20: Double)
        ) -> Bool {
            sample.fill < 60 && sample.background > 250
                && (8...22).contains(sample.below6)
                && (3...11).contains(sample.below20)
        }
        let deadline = Date().addingTimeInterval(2)
        var sample = render()
        while !shadowIsDrawn(sample), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            sample = render()
        }
        window.isHidden = true
        // Relative to the white background (top-right corner, beside the back button):
        // Figma is about 15 darker at +6 and 7 at +20. No shadow gives 0; a second copy
        // would give about 29 and 14, past both ranges.
        XCTAssertLessThan(sample.fill, 60, "banner fill above its bottom edge")
        XCTAssertGreaterThan(sample.background, 250, "white background")
        XCTAssertTrue((8...22).contains(sample.below6), "shadow 6pt below darkens \(sample.below6), Figma 15")
        XCTAssertTrue((3...11).contains(sample.below20), "shadow 20pt below darkens \(sample.below20), Figma 7")
    }

    /// Figma BODY 4023:2016: Products 14pt under the handle, sections 24pt apart.
    func testSheetSectionSpacingMatchesFigma() {
        XCTAssertEqual(HomeSheetMetrics.productsTopSpacing, 14)
        XCTAssertEqual(HomeSheetMetrics.sectionSpacing, 24)
        XCTAssertEqual(HomeSheetMetrics.bottomSpacing, 16)
    }

    /// English category copy is "Scones" (was "Savory Scones"); other languages keep theirs.
    func testSconesCategoryCopy() {
        let key = "home.products.category.savoryScones"
        XCTAssertEqual(HomeLocalizedString.string(key, locale: Locale(identifier: "en")), "Scones")
        XCTAssertEqual(HomeLocalizedString.string(key, locale: Locale(identifier: "sk")), "Pagáče")
        XCTAssertEqual(HomeLocalizedString.string(key, locale: Locale(identifier: "hu")), "Pogácsa")
    }

    /// Figma 6093:5981: 40pt icons 10pt under the status bar and 20pt from the edges,
    /// greeting 16pt under the icons, loyalty card 12pt under the greeting.
    func testHeaderMetricsMatchFigmaDashboard() {
        XCTAssertEqual(HomeHeaderMetrics.iconSize, 40)
        XCTAssertGreaterThanOrEqual(HomeHeaderMetrics.tapTargetSize, 44)
        XCTAssertEqual(HomeHeaderMetrics.headerRowTopPadding + HomeHeaderMetrics.tapTargetInset, 10)
        XCTAssertEqual(HomeHeaderMetrics.headerHorizontalPadding + HomeHeaderMetrics.tapTargetInset, 20)
        // Greeting and loyalty card: Figma x 20, width 362 on 402, like the icons.
        XCTAssertEqual(HomeHeaderMetrics.contentHorizontalInset, 20)
        XCTAssertEqual(HomeHeaderMetrics.contentHorizontalInset, HomeHeaderMetrics.headerHorizontalInset)
        let iconBottom = HomeHeaderMetrics.headerRowTopPadding
            + HomeHeaderMetrics.tapTargetInset
            + HomeHeaderMetrics.iconSize
        let greetingTop = HomeHeaderMetrics.headerRowTopPadding
            + HomeHeaderMetrics.tapTargetSize
            + HomeHeaderMetrics.greetingTopPadding
        XCTAssertEqual(greetingTop - iconBottom, 16)
        XCTAssertEqual(HomeHeaderMetrics.loyaltyCardTopSpacing, 12)
    }
}

private struct UnusedHomeNetworkClient: NetworkClient {
    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        throw NetworkError.invalidURL
    }

    func request<T: Decodable, B: Encodable>(_ path: String, method: HTTPMethod, body: B) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ url: URL) async throws -> Data {
        throw NetworkError.invalidURL
    }
}

private struct StubProfileRepository: ProfileRepository {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? { nil }
}
