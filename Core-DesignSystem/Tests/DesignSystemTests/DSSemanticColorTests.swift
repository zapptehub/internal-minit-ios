import XCTest
@testable import DesignSystem

final class DSSemanticColorTests: XCTestCase {
    func testEverySemanticRoleAliasesItsApprovedToken() {
        XCTAssertEqual(
            [
                "brand.secondary": DSPrimitiveColor.DeepClaret.tone500,
                "brand.secondarySubtle": DSPrimitiveColor.DeepClaret.tone100,
                "text.primary": DSPrimitiveColor.Grey.tone900,
                "text.secondary": DSPrimitiveColor.Grey.tone600,
                "text.heading": DSPrimitiveColor.Brown.tone500,
                "text.tertiary": DSPrimitiveColor.Grey.tone300,
                "text.active": DSPrimitiveColor.Grey.tone900,
                "text.disabled": DSPrimitiveColor.Grey.tone300,
                "text.inverse": DSPrimitiveColor.white,
                "text.onColorButton": DSPrimitiveColor.white,
                "text.error": DSPrimitiveColor.Red.tone700,
                "text.success": DSPrimitiveColor.Green.tone700,
                "text.accent": DSPrimitiveColor.Minit.tone400,
                "text.link": DSPrimitiveColor.Blue.tone500,
                "background.layer0": DSPrimitiveColor.white,
                "background.layer1": DSPrimitiveColor.Grey.tone50,
                "background.button.primary": DSPrimitiveColor.Minit.tone400,
                "background.button.secondary": DSPrimitiveColor.DeepClaret.tone500,
                "background.button.tertiary": DSPrimitiveColor.black,
                "background.button.disabled": DSPrimitiveColor.Grey.tone50,
                "background.button.accent": DSPrimitiveColor.Minit.tone500,
                "background.brown": DSPrimitiveColor.Brown.tone500,
                "background.pink": DSPrimitiveColor.DeepClaret.tone500,
                "background.green": DSPrimitiveColor.DeepGreen.tone500,
                "background.orange": DSPrimitiveColor.Minit.tone400,
                "background.control.selected": DSPlatformColorExtension.controlSelected,
                "background.icon.success": DSPrimitiveColor.Green.tone600,
                "background.icon.loading": DSPlatformColorExtension.iconBackgroundLoading,
                "icon.primary": DSPrimitiveColor.Grey.tone900,
                "icon.secondary": DSPrimitiveColor.Grey.tone600,
                "icon.active": DSPrimitiveColor.Grey.tone900,
                "icon.disabled": DSPrimitiveColor.Grey.tone300,
                "border.default": DSPrimitiveColor.Grey.tone100,
                "border.active": DSPrimitiveColor.Grey.tone400,
                "border.error": DSPrimitiveColor.Red.tone500,
                "border.success": DSPrimitiveColor.Green.tone500,
                "border.disabled": DSPrimitiveColor.Grey.tone100
            ],
            [
                "brand.secondary": DSSemanticColor.Brand.secondary,
                "brand.secondarySubtle": DSSemanticColor.Brand.secondarySubtle,
                "text.primary": DSSemanticColor.Text.primary,
                "text.secondary": DSSemanticColor.Text.secondary,
                "text.heading": DSSemanticColor.Text.heading,
                "text.tertiary": DSSemanticColor.Text.tertiary,
                "text.active": DSSemanticColor.Text.active,
                "text.disabled": DSSemanticColor.Text.disabled,
                "text.inverse": DSSemanticColor.Text.inverse,
                "text.onColorButton": DSSemanticColor.Text.onColorButton,
                "text.error": DSSemanticColor.Text.error,
                "text.success": DSSemanticColor.Text.success,
                "text.accent": DSSemanticColor.Text.accent,
                "text.link": DSSemanticColor.Text.link,
                "background.layer0": DSSemanticColor.Background.Layer.level0,
                "background.layer1": DSSemanticColor.Background.Layer.level1,
                "background.button.primary": DSSemanticColor.Background.Button.primary,
                "background.button.secondary": DSSemanticColor.Background.Button.secondary,
                "background.button.tertiary": DSSemanticColor.Background.Button.tertiary,
                "background.button.disabled": DSSemanticColor.Background.Button.disabled,
                "background.button.accent": DSSemanticColor.Background.Button.accent,
                "background.brown": DSSemanticColor.Background.brown,
                "background.pink": DSSemanticColor.Background.pink,
                "background.green": DSSemanticColor.Background.green,
                "background.orange": DSSemanticColor.Background.orange,
                "background.control.selected": DSSemanticColor.Background.Control.selected,
                "background.icon.success": DSSemanticColor.Background.Icon.success,
                "background.icon.loading": DSSemanticColor.Background.Icon.loading,
                "icon.primary": DSSemanticColor.Icon.primary,
                "icon.secondary": DSSemanticColor.Icon.secondary,
                "icon.active": DSSemanticColor.Icon.active,
                "icon.disabled": DSSemanticColor.Icon.disabled,
                "border.default": DSSemanticColor.Border.default,
                "border.active": DSSemanticColor.Border.active,
                "border.error": DSSemanticColor.Border.error,
                "border.success": DSSemanticColor.Border.success,
                "border.disabled": DSSemanticColor.Border.disabled
            ]
        )
    }

    func testPlatformColorExtensionsRemainExplicit() {
        XCTAssertEqual(DSPlatformColorExtension.controlSelected.rgb, 0x12B76A)
        XCTAssertEqual(
            DSPlatformColorExtension.controlSelected.sourceID,
            "platform:legacy:control-selected"
        )
        XCTAssertEqual(DSPlatformColorExtension.iconBackgroundLoading.rgb, 0xEDEDED)
        XCTAssertEqual(
            DSPlatformColorExtension.iconBackgroundLoading.sourceID,
            "platform:legacy:icon-background-loading"
        )
        XCTAssertEqual(DSPlatformColorExtension.loyaltyButtonBorder.rgb, 0xDFDFDF)
        XCTAssertEqual(
            DSPlatformColorExtension.loyaltyButtonBorder.sourceID,
            "platform:legacy:loyalty-button-border"
        )
        XCTAssertEqual(DSPlatformColorExtension.backgroundGradientTop.rgb, 0xFF8300)
        XCTAssertEqual(DSPlatformColorExtension.backgroundGradientPeach.rgb, 0xFFC78F)
        XCTAssertEqual(DSPlatformColorExtension.backgroundGradientCream.rgb, 0xFFF1E0)
    }
}
