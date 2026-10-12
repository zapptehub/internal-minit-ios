import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// The pink "%" badge on a product circle keeps the default size and the same
/// offset from that circle when Dynamic Type grows. The label under the circle
/// still scales; the badge does not.
@MainActor
final class CircleItemDiscountBadgeTests: XCTestCase {
    func testDiscountBadgeDoesNotScaleOrMove() throws {
        let large = try Self.measure(dynamicType: .large)
        let grown = try Self.measure(dynamicType: .accessibility2)
        let largest = try Self.measure(dynamicType: .accessibility5)

        XCTAssertEqual(large.pink.width, DSCircleItemList.badgeDiameter, accuracy: 2)
        XCTAssertEqual(large.pink.height, DSCircleItemList.badgeDiameter, accuracy: 2)
        for sample in [grown, largest] {
            XCTAssertEqual(sample.pink.width, large.pink.width, accuracy: 1.5)
            XCTAssertEqual(sample.pink.height, large.pink.height, accuracy: 1.5)
            XCTAssertEqual(sample.mark.width, large.mark.width, accuracy: 2)
            XCTAssertEqual(sample.mark.height, large.mark.height, accuracy: 2)
            // Hung off the same corner of the 56pt product circle. The circle's
            // visible grey changes as the pastry is cropped, so the anchor is the
            // circle frame implied by the badge's Figma offsets, not the photo.
            XCTAssertEqual(
                sample.pink.midX - CGFloat(sample.circle.minX),
                large.pink.midX - CGFloat(large.circle.minX),
                accuracy: 2
            )
            XCTAssertEqual(
                CGFloat(sample.pink.minY - sample.circle.minY),
                CGFloat(large.pink.minY - large.circle.minY),
                accuracy: 2
            )
        }
        // A scaled 13pt "%" at accessibility sizes fills the 20pt disc.
        XCTAssertLessThan(large.mark.width, large.pink.width - 4)
        XCTAssertLessThan(largest.mark.width, largest.pink.width - 4)
    }

    private struct Sample {
        var circle: ProgressDiscCenteringTests.Box
        var pink: ProgressDiscCenteringTests.Box
        var mark: ProgressDiscCenteringTests.Box
    }

    private static func measure(dynamicType: DynamicTypeSize) throws -> Sample {
        let list = DSCircleItemList(
            title: "Products",
            items: [.init(id: 0, image: .mockPasteryImage2, label: "Bread", showDiscount: true)],
            onItemTap: {},
            onSeeAllTap: {}
        )
        .frame(width: 220, alignment: .leading)
        .padding(24)
        .background(Color.white)
        let raster = try ProgressDiscCenteringTests.render(list, size: CGSize(width: 268, height: 360), dynamicType: dynamicType)
        let pink = try XCTUnwrap(raster.bbox { r, g, b in
            r > 160 && g < 90 && b > 60 && Int(r) > Int(g) + 70
        }, "missing badge at \(dynamicType)")
        let mark = try XCTUnwrap(markBox(in: raster, pink: pink), "missing % at \(dynamicType)")
        let circle = try XCTUnwrap(circleBox(in: raster, pink: pink), "missing product circle at \(dynamicType)")
        return Sample(circle: circle, pink: pink, mark: mark)
    }

    /// Light pixels of the "%" inside the pink disc, not the white ring outside it.
    private static func markBox(in raster: ProgressDiscCenteringTests.Raster, pink: ProgressDiscCenteringTests.Box) -> ProgressDiscCenteringTests.Box? {
        let cx = pink.midX
        let cy = pink.midY
        let rx = pink.width / 2
        let ry = pink.height / 2
        return raster.bbox { x, y, r, g, b in
            let dx = (CGFloat(x) - cx) / rx
            let dy = (CGFloat(y) - cy) / ry
            guard dx * dx + dy * dy < 0.82 else { return false }
            return r > 210 && g > 210 && b > 210
        }
    }

    /// Grey ring of the product disc (`#F2F2F2`). Only chords about 56pt wide count,
    /// so a taller label cannot stretch the box.
    private static func circleBox(in raster: ProgressDiscCenteringTests.Raster, pink: ProgressDiscCenteringTests.Box) -> ProgressDiscCenteringTests.Box? {
        raster.bbox { x, y, r, g, b in
            guard abs(Int(r) - 242) < 8, abs(Int(g) - 242) < 8, abs(Int(b) - 242) < 8 else { return false }
            let nearBadge = x < pink.maxX + 8 && y > pink.minY - 8 && y < pink.maxY + 70
            return nearBadge
        }
    }
}

private extension ProgressDiscCenteringTests.Raster {
    func bbox(_ match: (Int, Int, UInt8, UInt8, UInt8) -> Bool) -> ProgressDiscCenteringTests.Box? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                if match(x, y, bytes[i], bytes[i + 1], bytes[i + 2]) {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= 0 else { return nil }
        return ProgressDiscCenteringTests.Box(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
    }
}
