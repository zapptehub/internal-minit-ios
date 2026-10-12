import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// System styles follow the body text style with no accessibility cap, and stay
/// on their design size at the default content size (`.large`).
@MainActor
final class FontTypeDynamicTypeTests: XCTestCase {
    func testSystemPointSizesAreUnchangedAtTheDefaultContentSize() throws {
        let traits = UITraitCollection(preferredContentSizeCategory: .large)
        let metrics = UIFontMetrics(forTextStyle: .body)
        for style in Self.systemStyles {
            let spec = try XCTUnwrap(style.systemFontSpec, "\(style)")
            let scaled = metrics.scaledValue(for: spec.size, compatibleWith: traits)
            XCTAssertEqual(scaled, spec.size, accuracy: 0.001, "\(style)")
            let resolved = style.scaledSystemFont(for: .large)
            XCTAssertNotNil(resolved)
        }
        XCTAssertNil(FontType.headingH2.systemFontSpec)
        XCTAssertNil(FontType.headingH2.scaledSystemFont(for: .accessibility5))
    }

    func testUiRegularMatchesTheFixedSystemFontAtLargeAndGrowsPastDoubleAtAccessibility5() {
        let large = Self.textHeight(Text("Ag").typography(.uiRegular), dynamicType: .large)
        let fixed = Self.textHeight(
            Text("Ag").font(.system(size: 13, weight: .regular)),
            dynamicType: .large
        )
        let grown = Self.textHeight(Text("Ag").typography(.uiRegular), dynamicType: .accessibility5)
        XCTAssertEqual(large, fixed, accuracy: 0.75, "default \(large) fixed \(fixed)")

        let traits = UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: 13, compatibleWith: traits)
        XCTAssertGreaterThan(scaled / 13, 2, "body metrics must not cap below 2× at AX5")
        XCTAssertGreaterThan(grown / large, 2, "rendered \(grown) vs \(large)")
    }

    func testLongestWordFitsTheLineAtAccessibility5AndIsUnscaledWhenItAlreadyFits() {
        let welcome = DynamicTypeWordFitting.uiFont(for: .headingLargeSemibold, dynamicTypeSize: .accessibility5)
        let width: CGFloat = 320
        let scale = DynamicTypeWordFitting.scale(for: "Welcome back", font: welcome, width: width)
        XCTAssertLessThan(scale, 1)
        let fitted = welcome.withSize(welcome.pointSize * scale)
        let word = ("Welcome" as NSString).size(withAttributes: [.font: fitted]).width
        XCTAssertLessThanOrEqual(word, width + 0.5)

        let short = DynamicTypeWordFitting.scale(for: "Hi", font: welcome, width: width)
        XCTAssertEqual(short, 1, accuracy: 0.001)

        let atDefault = DynamicTypeWordFitting.uiFont(for: .uiRegular, dynamicTypeSize: .large)
        XCTAssertEqual(atDefault.pointSize, 13, accuracy: 0.001)
        XCTAssertEqual(
            DynamicTypeWordFitting.scale(for: "Continue", font: atDefault, width: width),
            1,
            accuracy: 0.001
        )
    }

    func testBodyMediumSmallLineBoxStaysTwentyAtLargeAndScalesAtAccessibility5() {
        let large = Self.textHeight(Text("Every bite").typography(.bodyMediumSmall), dynamicType: .large)
        let grown = Self.textHeight(Text("Every bite").typography(.bodyMediumSmall), dynamicType: .accessibility5)
        XCTAssertEqual(large, 20, accuracy: 0.75, "body \(large)")
        XCTAssertGreaterThan(grown, large * 2)
    }

    private static let systemStyles: [FontType] = [
        .paragraphLargeRegular,
        .paragraphRegular,
        .paragraphBold,
        .bodyMediumSmall,
        .bodyBoldLabel,
        .bodyBoldMedium,
        .uiLargeBold,
        .uiLargeRegular,
        .uiRegular,
        .uiSmallSemibold,
        .uiCaptionMedium
    ]

    private static func textHeight<V: View>(_ view: V, dynamicType: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(
            rootView: view.environment(\.dynamicTypeSize, dynamicType).fixedSize()
        )
        host.safeAreaRegions = []
        return host.sizeThatFits(in: CGSize(width: 800, height: 800)).height
    }
}
