import DataProfile
import XCTest
@testable import FeatureHome

final class FeatureHomeTests: XCTestCase {
    @MainActor
    func testCreateScreenBuilds() {
        _ = FeatureHome.createScreen(
            userId: "user-1",
            profileRepository: StubProfileRepository(),
            onLogOut: {}
        )
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

private struct StubProfileRepository: ProfileRepository {
    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? { nil }
}
