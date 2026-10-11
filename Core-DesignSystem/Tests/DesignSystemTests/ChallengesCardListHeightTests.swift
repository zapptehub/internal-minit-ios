import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Figma Challenge card (6143:1889) is 200 × 124. 124 is the minimum height.
/// At the default size the 16pt padding, 40pt ring and a two-line title fit in
/// that card (124 − 32 = 92pt for the ring and the title). At accessibility
/// XXXL the card grows so the two title lines are not clipped, and every card
/// in the row is as tall as the tallest one.
/// The title (6143:1898) is Sharp Grotesk SmBold 20, 15pt, line height 20,
/// trimmed to cap height and last baseline: a two-line box of cap + 20 ≈ 31pt,
/// leaving Figma's 21pt between the ring and the first cap.
@MainActor
final class ChallengesCardListHeightTests: XCTestCase {
    private static let titles = [
        "Use the minit loyalty card 4 times",
        "Buy 1 Pizza or any other type of bakery",
        "Add a Coffee to your morning breakfast",
        "Taste multiple Minit bakery types",
    ]

    func testCardSizeMatchesFigma() {
        XCTAssertEqual(DSChallengesCardList.cardSize, CGSize(width: 200, height: 124))
    }

    func testCornerRadiusMatchesFigma() {
        XCTAssertEqual(DSChallengesCardList.cornerRadius, 16)
        // The shared card radius stays 20; only the Challenges cards use 16.
        XCTAssertEqual(DSRadius.card, 20)
    }

    /// Figma "Small" effect: #3E3445 at 0x0A, (0, 2) blur 4; #3E3445 at 0x1A, (0, 16) blur 32
    /// spread −4. SwiftUI radius = blur / 2.
    func testShadowMatchesFigmaSmallEffect() {
        let small = DSShadow.small
        XCTAssertEqual(Self.rgba(DSShadow.smallColor), [0x3E, 0x34, 0x45, 255])
        XCTAssertEqual(Self.rgba(small.near.color), [0x3E, 0x34, 0x45, 0x0A])
        XCTAssertEqual(small.near.radius, 2)
        XCTAssertEqual(small.near.x, 0)
        XCTAssertEqual(small.near.y, 2)
        XCTAssertEqual(Self.rgba(small.far.color), [0x3E, 0x34, 0x45, 0x1A])
        XCTAssertEqual(small.far.radius, 16)
        XCTAssertEqual(small.far.x, 0)
        XCTAssertEqual(small.far.y, 16)
        // Figma spread −4 → the far caster is inset 4 on every side.
        XCTAssertEqual(small.farCasterInset, 4)
        // The Challenge cards use the shared token.
        Self.assertSameShadow(DSChallengesCardList.shadow, small)
        // Shared token unchanged.
        XCTAssertEqual(DSShadow.card.radius, DSRadius.media)
        XCTAssertEqual(DSShadow.card.y, DSMetric.Spacing.small)
    }

    static func assertSameShadow(
        _ actual: DSLayeredShadowToken,
        _ expected: DSLayeredShadowToken,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (a, e) in [(actual.near, expected.near), (actual.far, expected.far)] {
            XCTAssertEqual(rgba(a.color), rgba(e.color), file: file, line: line)
            XCTAssertEqual([a.radius, a.x, a.y], [e.radius, e.x, e.y], file: file, line: line)
        }
        XCTAssertEqual(actual.farCasterInset, expected.farCasterInset, file: file, line: line)
    }

    static func rgba(_ color: Color) -> [Int] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a].map { Int(($0 * 255).rounded()) }
    }

    func testTitleStyleMatchesFigma() {
        XCTAssertEqual(DSChallengesCardList.titleStyle, .headingSmall)
        XCTAssertEqual(DSChallengesCardList.titleStyle.tracking, 0)
        XCTAssertNil(DSChallengesCardList.titleStyle.figmaLineBox)
        XCTAssertEqual(DSChallengesCardList.titlePointSize, 15)
        XCTAssertEqual(DSChallengesCardList.titleLineSpacing, 5)
        XCTAssertEqual(DSChallengesCardList.titleFollowingGap, 16)
        let font = SharpGroteskFontMetrics.uiFont(pointSize: DSChallengesCardList.titlePointSize)
        XCTAssertEqual(font.fontName, "SharpGroteskSmBold20-Regular")
        XCTAssertEqual(font.pointSize, 15)
    }

    func testCardsAre124TallAtTheDefaultSize() {
        for title in Self.titles + ["Pizza", "Fresh loaf\ntoday"] {
            XCTAssertEqual(Self.cardHeight(title, size: .large), 124, accuracy: 0.75, title)
        }
        XCTAssertEqual(
            Self.rowHeight(["Pizza", "Fresh loaf\ntoday"], size: .large),
            124,
            accuracy: 0.75
        )
        let list = DSChallengesCardList(
            title: "Challenges",
            items: [
                .init(id: 0, backgroundColor: .orange, icon: .croissant, badgeText: "+45 pts", title: "Pizza"),
                .init(
                    id: 1,
                    backgroundColor: .green,
                    icon: .qrScanLine,
                    badgeText: "+45 pts",
                    title: "Fresh loaf\ntoday"
                ),
            ]
        )
        let host = UIHostingController(rootView: list.environment(\.dynamicTypeSize, .large))
        let size = host.sizeThatFits(in: CGSize(width: 402, height: CGFloat.greatestFiniteMagnitude))
        // 24pt header row, 12pt to the cards, 124pt cards.
        XCTAssertEqual(size.height, 24 + 12 + 124, accuracy: 1)
    }

    /// accessibilityExtraExtraExtraLarge, the largest accessibility size (XXXL).
    func testCardsGrowTogetherAtAccessibilityXXXLSoTheTwoLineTitleFits() {
        // Short enough that accessibility XXXL still wraps this as two lines,
        // not three. "Fresh loaf" alone overflows the 168pt text width at that size.
        let longTitle = "Loaf\ntoday"
        let oneLine = Self.cardHeight("Pizza", size: .accessibility5)
        let twoLine = Self.cardHeight(longTitle, size: .accessibility5)
        XCTAssertGreaterThan(twoLine, 124, longTitle)
        XCTAssertGreaterThan(twoLine, oneLine + 8, "a second line should make the card taller on its own")

        let limited = Self.titleBoxHeight(longTitle, lineLimit: 2, size: .accessibility5)
        let unlimited = Self.titleBoxHeight(longTitle, lineLimit: nil, size: .accessibility5)
        XCTAssertEqual(limited, unlimited, accuracy: 0.75, "\(longTitle) is truncated")
        let topRow = max(DSChallengesCardList.iconCircleDiameter, Self.badgeHeight(size: .accessibility5))
        let padding = DSConstant.mediumLarge.value
        XCTAssertGreaterThanOrEqual(
            twoLine + 0.5,
            padding * 2 + topRow + limited,
            "\(longTitle) does not fit in the card"
        )

        let titles = ["Pizza", longTitle]
        let row = Self.rowHeight(titles, size: .accessibility5)
        XCTAssertEqual(row, twoLine, accuracy: 0.75)
        let placed = Self.placedCardHeights(titles, size: .accessibility5)
        XCTAssertEqual(placed.count, 2)
        XCTAssertEqual(placed[0], placed[1], accuracy: 2, "cards in the row differ")
        XCTAssertEqual(placed[0], row, accuracy: 8)
    }

    func testTwoLineTitlesFitWithoutTruncation() {
        let padding = DSConstant.mediumLarge.value
        let titleWidth = DSChallengesCardList.cardSize.width - padding * 2
        let available = DSChallengesCardList.cardSize.height - padding * 2 - DSChallengesCardList.iconCircleDiameter
        let cap = SharpGroteskFontMetrics.uiFont(pointSize: DSChallengesCardList.titlePointSize).capHeight
        for title in Self.titles {
            let limited = Self.titleBoxHeight(title, lineLimit: 2, width: titleWidth)
            let unlimited = Self.titleBoxHeight(title, lineLimit: nil, width: titleWidth)
            let ringToCap = available - limited
            XCTAssertEqual(limited, unlimited, accuracy: 0.5, "\(title) is truncated")
            // Two lines: cap of the first + one 20pt baseline-to-baseline step.
            XCTAssertEqual(limited, cap + DSChallengesCardList.titleLineHeight, accuracy: 0.75, "\(title) box")
            XCTAssertLessThanOrEqual(limited, available, "\(title) does not fit")
            XCTAssertEqual(ringToCap, 21, accuracy: 0.75, "\(title) ring to cap")
        }
    }

    private static func cardHeight(_ title: String, size: DynamicTypeSize) -> CGFloat {
        let card = DSChallengesCard(
            item: .init(
                id: 0,
                backgroundColor: .orange,
                icon: .croissant,
                badgeText: "+45 pts",
                title: title
            )
        )
        let host = UIHostingController(rootView: card.environment(\.dynamicTypeSize, size))
        return host.sizeThatFits(in: CGSize(width: DSChallengesCardList.cardSize.width, height: .greatestFiniteMagnitude)).height
    }

    private static func rowHeight(_ titles: [String], size: DynamicTypeSize) -> CGFloat {
        let host = UIHostingController(rootView: Self.row(titles).environment(\.dynamicTypeSize, size))
        return host.sizeThatFits(in: CGSize(width: 800, height: CGFloat.greatestFiniteMagnitude)).height
    }

    private static func badgeHeight(size: DynamicTypeSize) -> CGFloat {
        let badge = DSChallengesCardList.badge(text: "+45 pts").environment(\.dynamicTypeSize, size)
        return UIHostingController(rootView: badge)
            .sizeThatFits(in: CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
            .height
    }

    /// Heights of the red and blue cards after the row has stretched them.
    private static func placedCardHeights(_ titles: [String], size: DynamicTypeSize) -> [CGFloat] {
        let renderer = ImageRenderer(content: Self.row(titles).environment(\.dynamicTypeSize, size))
        renderer.scale = 1
        guard let image = renderer.cgImage else {
            XCTFail("card row did not render")
            return []
        }
        let scale = CGFloat(image.width) / (DSChallengesCardList.cardSize.width * 2 + DSChallengesCardList.itemSpacing)
        let sampleX = [10, DSChallengesCardList.cardSize.width + DSChallengesCardList.itemSpacing + 10]
            .map { Int(($0 * scale).rounded()) }
        return sampleX.map { x in
            CGFloat(Self.matchingRows(in: image, x: x).count) / scale
        }
    }

    private static func row(_ titles: [String]) -> DSChallengesCardRow {
        DSChallengesCardRow(
            items: titles.enumerated().map { index, title in
                .init(
                    id: index,
                    backgroundColor: index == 0
                        ? Color(red: 1, green: 0, blue: 0)
                        : Color(red: 0, green: 0, blue: 1),
                    icon: .croissant,
                    badgeText: "+45 pts",
                    title: title
                )
            }
        )
    }

    /// Rows whose pixel at `x` is the card fill (pure red or pure blue), skipping
    /// the rounded-corner pixels that are not the fill.
    private static func matchingRows(in image: CGImage, x: Int) -> Range<Int> {
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn, x >= 0, x < width else { return 0..<0 }
        var first: Int?
        var last: Int?
        for y in 0..<height {
            let i = (y * width + x) * 4
            let red = pixels[i]
            let green = pixels[i + 1]
            let blue = pixels[i + 2]
            let isFill = (red > 200 && green < 40 && blue < 40) || (blue > 200 && red < 40 && green < 40)
            if isFill {
                if first == nil { first = y }
                last = y
            }
        }
        guard let first, let last else { return 0..<0 }
        return first..<(last + 1)
    }

    private static func titleBoxHeight(_ title: String, lineLimit: Int?, size: DynamicTypeSize) -> CGFloat {
        let category: UIContentSizeCategory = size == .accessibility5
            ? .accessibilityExtraExtraExtraLarge
            : .large
        let spacing = UIFontMetrics(forTextStyle: .body).scaledValue(
            for: DSChallengesCardList.titleLineSpacing,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: category)
        )
        let view = SharpGroteskCapTrim(followingGap: DSChallengesCardList.titleFollowingGap) {
            Text(title)
                .typography(DSChallengesCardList.titleStyle)
                .lineSpacing(spacing)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        }
        let width = DSChallengesCardList.cardSize.width - DSConstant.mediumLarge.value * 2
        let host = UIHostingController(
            rootView: view.frame(width: width, alignment: .leading).environment(\.dynamicTypeSize, size)
        )
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    private static func titleBoxHeight(_ title: String, lineLimit: Int?, width: CGFloat) -> CGFloat {
        let view = SharpGroteskCapTrim(followingGap: DSChallengesCardList.titleFollowingGap) {
            Text(title)
                .typography(DSChallengesCardList.titleStyle)
                .lineSpacing(DSChallengesCardList.titleLineSpacing)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
        }
        let host = UIHostingController(
            rootView: view.frame(width: width, alignment: .leading).environment(\.dynamicTypeSize, .large)
        )
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}
