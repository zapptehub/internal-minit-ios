import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// `.darkOrange` pairs `.tertiary`'s black fill with `darkOrangeButtonLabel`
/// (`Minit.tone600`, `#CE6900`). Other solid types keep their existing colours.
@MainActor
final class DSButtonDarkOrangeTests: XCTestCase {
    func testDarkOrangeUsesBlackFillAndTone600Label() {
        let button = DSButton(title: "Try Minit in Demo mode", type: .darkOrange) {}
        XCTAssertEqual(
            DSPlatformColorExtension.darkOrangeButtonLabel,
            DSPrimitiveColor.Minit.tone600
        )
        XCTAssertEqual(DSPlatformColorExtension.darkOrangeButtonLabel.rgb, 0xCE6900)
        XCTAssertEqual(
            rgba(button.labelColor),
            rgba(DSPlatformColorExtension.darkOrangeButtonLabel.color)
        )
        XCTAssertEqual(rgba(button.labelColor), [0xCE, 0x69, 0x00, 0xFF])
        XCTAssertEqual(rgba(button.backgroundColor), rgba(DSColor.Background.Button.tertiary))
        XCTAssertEqual(rgba(button.backgroundColor), [0x00, 0x00, 0x00, 0xFF])
        XCTAssertEqual(button.labelFont, .uiLargeBold)
    }

    func testDarkOrangeDisabledUsesTheSharedDisabledTokens() {
        let button = DSButton(title: "Try Minit in Demo mode", type: .darkOrange, isEnabled: false) {}
        XCTAssertEqual(rgba(button.labelColor), rgba(DSColor.Text.disabled))
        XCTAssertEqual(rgba(button.backgroundColor), rgba(DSColor.Background.Button.disabled))
    }

    func testExistingSolidTypesKeepTheirColors() {
        let primary = DSButton(title: "Get started", type: .primary) {}
        XCTAssertEqual(rgba(primary.labelColor), rgba(DSColor.Text.onColorButton))
        XCTAssertEqual(rgba(primary.backgroundColor), rgba(DSColor.Background.Button.primary))

        let tertiary = DSButton(title: "Reset", type: .tertiary) {}
        XCTAssertEqual(rgba(tertiary.labelColor), rgba(DSColor.Text.onColorButton))
        XCTAssertEqual(rgba(tertiary.backgroundColor), rgba(DSColor.Background.Button.tertiary))

        let social = DSButton(title: "Apple", type: .social) {}
        XCTAssertEqual(rgba(social.labelColor), rgba(DSColor.Text.primary))
        XCTAssertEqual(rgba(social.backgroundColor), rgba(DSColor.Background.Button.disabled))
    }

    func testDarkOrangeMatchesThePrimaryHeight() {
        let width: CGFloat = 362
        let primary = height(DSButton(title: "Get started", type: .primary) {}, width: width)
        let demo = height(DSButton(title: "Try Minit in Demo mode", type: .darkOrange) {}, width: width)
        XCTAssertEqual(demo, DSButtonHeightStyle.regular.value, accuracy: 0.75)
        XCTAssertEqual(demo, primary, accuracy: 0.75)
    }

    private func rgba(_ color: Color) -> [Int] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { Int(($0 * 255).rounded()) }
    }

    private func height<V: View>(_ view: V, width: CGFloat) -> CGFloat {
        let host = UIHostingController(
            rootView: view
                .environment(\.dynamicTypeSize, DynamicTypeSize.large)
                .frame(width: width)
        )
        host.safeAreaRegions = []
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}
