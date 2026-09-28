import XCTest
@testable import DesignSystem

/// Fails on the previous status card: padding was `DSConstant.large` (24),
/// the title→subtitle gap was `DSConstant.xSmall` (4), and the title style
/// was `uiLargeBold`.
final class StatusCardMetricsTests: XCTestCase {
    func testMetricsUseTheFigmaScaleAndExistingStyles() {
        XCTAssertEqual(StatusCardMetrics.contentPadding, 32)
        XCTAssertEqual(StatusCardMetrics.contentPadding, DSConstant.xLarge.value)
        XCTAssertNotEqual(StatusCardMetrics.contentPadding, DSConstant.large.value)

        XCTAssertEqual(StatusCardMetrics.iconToTextSpacing, 24)
        XCTAssertEqual(StatusCardMetrics.iconToTextSpacing, DSConstant.large.value)

        XCTAssertEqual(StatusCardMetrics.titleToSubtitleSpacing, 8)
        XCTAssertEqual(StatusCardMetrics.titleToSubtitleSpacing, DSConstant.small.value)
        XCTAssertNotEqual(StatusCardMetrics.titleToSubtitleSpacing, DSConstant.xSmall.value)

        XCTAssertEqual(StatusCardMetrics.cornerRadius, 20)
        XCTAssertEqual(StatusCardMetrics.cornerRadius, DSConstant.cardCornerRadius.value)
        XCTAssertEqual(StatusCardMetrics.iconDiameter, 48)
        XCTAssertEqual(StatusCardMetrics.glyphSize, 24)

        XCTAssertEqual(StatusCardMetrics.titleStyle, .headingMediumBold)
        XCTAssertNotEqual(StatusCardMetrics.titleStyle, .uiLargeBold)
        XCTAssertEqual(StatusCardMetrics.titleStyle.tracking, 0)
        XCTAssertEqual(StatusCardMetrics.titlePointSize, 20)
        XCTAssertEqual(StatusCardMetrics.titleBaselineToBaseline, 23)
        XCTAssertEqual(StatusCardMetrics.titleLineSpacing, 3)
        let font = SharpGroteskFontMetrics.uiFont(pointSize: StatusCardMetrics.titlePointSize)
        XCTAssertEqual(font.ascender - font.descender, StatusCardMetrics.titlePointSize, accuracy: 0.05)
        XCTAssertEqual(
            StatusCardMetrics.titleLineSpacing + (font.ascender - font.descender),
            StatusCardMetrics.titleBaselineToBaseline,
            accuracy: 0.05
        )
        XCTAssertEqual(StatusCardMetrics.subtitleStyle, .bodyMediumSmall)
        XCTAssertNotEqual(StatusCardMetrics.subtitleStyle, .paragraphRegular)
        XCTAssertEqual(StatusCardMetrics.subtitleStyle.tracking, 0)
        XCTAssertEqual(StatusCardMetrics.subtitleStyle.figmaLineBox?.lineHeight, 20)
        XCTAssertLessThan(
            StatusCardMetrics.subtitleStyle.figmaLineBox?.naturalLineHeight ?? 0,
            20
        )
        XCTAssertEqual(FontType.headingLargeSemibold.figmaLineBox?.lineHeight, 44)
        XCTAssertEqual(FontType.headingLargeSemibold.figmaLineBox?.naturalLineHeight, 40)
        XCTAssertEqual(FontType.headingLargeSemibold.figmaLineBox?.lineSpacing, 4)
        XCTAssertEqual(FontType.headingLargeSemibold.figmaLineBox?.halfLeading, 2)
        XCTAssertNil(FontType.paragraphRegular.figmaLineBox)
        XCTAssertEqual(FontType.paragraphRegular.tracking, 0)

        XCTAssertEqual(DSSemanticColor.Text.heading.rgb, 0x331A00)
        XCTAssertEqual(DSSemanticColor.Text.secondary.rgb, 0x666666)
        XCTAssertEqual(DSSemanticColor.Background.Layer.level0.rgb, 0xFFFFFF)
        XCTAssertEqual(
            StatusCardMetrics.titleColor.description,
            DSColor.Text.heading.description
        )
        XCTAssertEqual(
            StatusCardMetrics.subtitleColor.description,
            DSColor.Text.secondary.description
        )
        XCTAssertEqual(
            StatusCardMetrics.surface.description,
            DSColor.Background.Layer.level0.description
        )

        XCTAssertEqual(StatusCardMetrics.shadow.radius, DSShadow.card.radius)
        XCTAssertEqual(StatusCardMetrics.shadow.x, DSShadow.card.x)
        XCTAssertEqual(StatusCardMetrics.shadow.y, DSShadow.card.y)
        XCTAssertEqual(StatusCardMetrics.shadow.radius, 16)
        XCTAssertEqual(StatusCardMetrics.shadow.y, 8)
        XCTAssertEqual(StatusCardMetrics.shadow.x, 0)
    }
}
