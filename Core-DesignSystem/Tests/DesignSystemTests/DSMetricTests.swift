import CoreGraphics
import XCTest
@testable import DesignSystem

final class DSMetricTests: XCTestCase {
    func testGenericSpacingAndSizeResolveToTheModeOneScale() {
        XCTAssertEqual(
            [
                DSMetric.Spacing.zero,
                DSMetric.Spacing.xxSmall,
                DSMetric.Spacing.xSmall,
                DSMetric.Spacing.small,
                DSMetric.Spacing.medium,
                DSMetric.Spacing.mediumLarge,
                DSMetric.Spacing.large,
                DSMetric.Spacing.xLarge,
                DSMetric.Spacing.xxLarge
            ],
            [0, 2, 4, 8, 12, 16, 24, 32, 40]
        )
        XCTAssertEqual(
            [
                DSMetric.Size.iconExtraSmall,
                DSMetric.Size.iconSmall,
                DSMetric.Size.iconMedium,
                DSMetric.Size.iconLarge,
                DSMetric.Size.iconExtraLarge,
                DSMetric.Size.minimumTouchTarget
            ],
            [12, 16, 20, 24, 32, 48]
        )
        XCTAssertEqual(DSPlatformMetric.Spacing.smallMedium, 6)
        XCTAssertEqual(DSPlatformMetric.Size.contentMaxWidth, 600)
    }

    func testRadiusBorderAndComponentMetricsPreserveCurrentContracts() {
        XCTAssertEqual(
            [
                DSRadius.extraSmall,
                DSRadius.small,
                DSRadius.control,
                DSRadius.media,
                DSRadius.card
            ],
            [4, 8, 12, 16, 20]
        )
        XCTAssertEqual(
            [
                DSBorderWidth.hairline,
                DSBorderWidth.standard,
                DSBorderWidth.selectableIndicator
            ],
            [1, 2, 1.5]
        )
        XCTAssertEqual(
            [
                DSComponentMetric.Button.regularHeight,
                DSComponentMetric.Button.compactHeight,
                DSComponentMetric.Button.smallHeight,
                DSComponentMetric.Button.largeHeight,
                DSComponentMetric.Button.xLargeHeight
            ],
            [56, 36, 32, 48, 64]
        )
        XCTAssertEqual(DSComponentMetric.Input.fieldHeight, 48)
        XCTAssertEqual(DSComponentMetric.Input.numberCircleDiameter, 44)
        XCTAssertEqual(DSComponentMetric.SelectionControl.controlSize, 20)
        XCTAssertEqual(DSComponentMetric.SelectableRow.height, 56)
        XCTAssertEqual(DSComponentMetric.PinnedSheet.handleWidth, 36)
    }

    func testShadowsRetainTheCurrentPlatformHierarchy() {
        XCTAssertEqual(DSShadow.card.radius, 16)
        XCTAssertEqual(DSShadow.card.x, 0)
        XCTAssertEqual(DSShadow.card.y, 8)
        XCTAssertEqual(DSShadow.pinnedSheet.radius, 8)
        XCTAssertEqual(DSShadow.pinnedSheet.y, -2)
        XCTAssertEqual(DSShadow.loyaltyButton.radius, 2)
        XCTAssertEqual(DSShadow.loyaltyButton.y, 1)
    }

    func testLegacyConstantsRemainCompatibleAliases() {
        XCTAssertEqual(DSConstant.large.rawValue, 24)
        XCTAssertEqual(DSConstant.large.value, DSMetric.Spacing.large)
        XCTAssertEqual(DSConstant.cardCornerRadius.value, DSRadius.card)
    }
}
