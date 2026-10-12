import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Text buttons keep their Figma height at the default content size and grow
/// with the label above it, the way Android's minimum height does.
@MainActor
final class DSButtonMinimumHeightTests: XCTestCase {
    func testRegularButtonKeepsTheFigmaHeightAtTheDefaultContentSize() {
        let height = Self.height(
            DSButton(title: "Get started", type: .primary) {},
            dynamicType: .large,
            width: 362
        )
        XCTAssertEqual(height, DSButtonHeightStyle.regular.value, accuracy: 0.75)
    }

    func testLoyaltyChipKeepsTheLargeHeightAtTheDefaultContentSize() {
        let height = Self.height(
            DSButton(
                title: "Minit Card",
                type: .loyaltyCard,
                icon: .minitQrCode,
                heightStyle: .large
            ) {},
            dynamicType: .large,
            width: 320
        )
        XCTAssertEqual(height, DSButtonHeightStyle.large.value, accuracy: 0.75)
    }

    func testLoyaltyChipGrowsAtTheLargestAccessibilitySize() {
        let height = Self.height(
            DSButton(
                title: "Minit Card",
                type: .loyaltyCard,
                icon: .minitQrCode,
                heightStyle: .large
            ) {},
            dynamicType: .accessibility5,
            width: 320
        )
        XCTAssertGreaterThan(height, DSButtonHeightStyle.large.value)
    }

    func testWrappedLabelGrowsPastTheMinimumHeight() {
        let height = Self.height(
            DSButton(
                title: "Get started with a very long label",
                type: .primary
            ) {},
            dynamicType: .accessibility5,
            width: 160
        )
        XCTAssertGreaterThan(height, DSButtonHeightStyle.regular.value)
    }

    private static func height<V: View>(
        _ view: V,
        dynamicType: DynamicTypeSize,
        width: CGFloat
    ) -> CGFloat {
        let host = UIHostingController(
            rootView: view
                .environment(\.dynamicTypeSize, dynamicType)
                .frame(width: width)
        )
        host.safeAreaRegions = []
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}
