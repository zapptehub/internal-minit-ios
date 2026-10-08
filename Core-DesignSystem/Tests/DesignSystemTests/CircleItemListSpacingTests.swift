import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Figma Products (node 6154:1940): 24pt title row, 12pt gap, 56pt circles, so the
/// header center sits 24pt above the circle top, same as Challenges. The "%" badge
/// is level with the circle top and hangs 9.5pt past its right edge.
@MainActor
final class CircleItemListSpacingTests: XCTestCase {
    func testMetricsMatchFigma() {
        XCTAssertEqual(DSCircleItemList.rowTopInset, 4)
        XCTAssertEqual(DSCircleItemList.badgeTopOffset, 3)
        XCTAssertEqual(DSCircleItemList.badgeTrailingOffset, 12.5)
        // Pink disc (inside the 3pt white ring) lands level with the circle top...
        XCTAssertEqual(DSCircleItemList.badgeTopOffset - DSCircleItemList.badgeBorderWidth, 0)
        // ...and 9.5pt past the circle's right edge.
        XCTAssertEqual(DSCircleItemList.badgeTrailingOffset - DSCircleItemList.badgeBorderWidth, 9.5)
        // The ring rises 3pt above the circle; the row's top inset keeps it unclipped.
        XCTAssertGreaterThanOrEqual(DSCircleItemList.rowTopInset, DSCircleItemList.badgeTopOffset)
    }

    func testHeaderCenterToCircleTopIsFigmaTwentyFour() {
        let width: CGFloat = 402
        let list = Self.measure(
            DSCircleItemList(
                title: "Products",
                items: [.init(id: 0, image: .mockPasteryImage2, label: "Bread", showDiscount: true)]
            ),
            width: width
        )
        let header = Self.measure(DSCollectionHeader(title: "Products", onSeeAllTapped: {}), width: width)
        let label = Self.measure(
            Text("Bread").typography(.uiRegular).lineLimit(2).frame(width: DSCircleItemList.circleDiameter),
            width: width
        )
        // list = header + small (8) + rowTopInset + circle + small (8) + label
        let headerBottomToCircleTop = list.height - header.height - DSCircleItemList.circleDiameter -
            DSConstant.small.value - label.height
        let headerCenterToCircleTop = header.height / 2 + headerBottomToCircleTop
        print(
            "CIRCLES_FIGMA ios list=\(list.height) header=\(header.height) label=\(label.height) " +
            "headerBottomToCircle=\(headerBottomToCircleTop) centerToCircle=\(headerCenterToCircleTop)"
        )
        XCTAssertEqual(headerBottomToCircleTop, 12, accuracy: 0.5)
        XCTAssertEqual(headerCenterToCircleTop, 24, accuracy: 0.75)
    }

    private static func measure<V: View>(_ view: V, width: CGFloat) -> CGSize {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, .large))
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}
