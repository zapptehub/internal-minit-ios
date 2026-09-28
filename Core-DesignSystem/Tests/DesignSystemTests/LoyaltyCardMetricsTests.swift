import XCTest
@testable import DesignSystem

final class LoyaltyCardMetricsTests: XCTestCase {
    func testTextStylesUseExistingFontTypes() {
        XCTAssertEqual(LoyaltyCardMetrics.pointsStyle, .headingLargeBold)
        XCTAssertEqual(LoyaltyCardMetrics.rankTitleStyle, .headingMediumBold)
        XCTAssertEqual(LoyaltyCardMetrics.subtitleStyle, .uiCaptionMedium)
        XCTAssertEqual(LoyaltyCardMetrics.subtitleStyle.tracking, 0)
        XCTAssertEqual(LoyaltyCardMetrics.chipLabelStyle, .paragraphBold)

        XCTAssertEqual(LoyaltyCardMetrics.pointsStyle.tracking, -1.68)
        XCTAssertEqual(LoyaltyCardMetrics.rankTitleStyle.tracking, 0)
        XCTAssertEqual(LoyaltyCardMetrics.pointsFontSize, 56)
        XCTAssertEqual(LoyaltyCardMetrics.rankTitleFontSize, 20)

        XCTAssertEqual(LoyaltyCardMetrics.rankSubtitleSpacing, 6)
        XCTAssertEqual(LoyaltyCardMetrics.rankSubtitleSpacing, DSConstant.smallMedium.value)
        XCTAssertEqual(LoyaltyCardMetrics.sectionSpacing, 20)
        XCTAssertEqual(LoyaltyCardMetrics.chipIconSize, 24)
        XCTAssertEqual(LoyaltyCardMetrics.chipIconGap, 8)
        XCTAssertEqual(LoyaltyCardMetrics.chipIconGap, DSConstant.small.value)
        XCTAssertEqual(LoyaltyCardMetrics.pointsMinimumScaleFactor, 0.45, accuracy: 0.001)
        XCTAssertEqual(LoyaltyCardMetrics.illustrationClearance, 129)
    }

    func testColoursUseHeadingPrimaryAndTheSubtitleToken() {
        XCTAssertEqual(DSSemanticColor.Text.heading.rgb, 0x331A00)
        XCTAssertEqual(DSSemanticColor.Text.primary.rgb, 0x1A1A1A)
        XCTAssertEqual(DSPlatformColorExtension.loyaltyRankSubtitle.rgb, 0xA3A3A3)
        XCTAssertEqual(
            LoyaltyCardMetrics.rankSubtitleColor.description,
            DSPlatformColorExtension.loyaltyRankSubtitle.color.description
        )
    }
}
