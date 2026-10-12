import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Figma "Recept News" (6154:2056): Article 280 wide, padding 4, radius 16; photo 160 tall,
/// radius 12; Content padding 16; title Sharp Grotesk SmBold 20 14/18 `#331A00` trimmed to
/// cap height and last baseline; 8 between cards; 12 from the 24pt title row to the cards.
/// Two title lines make the card 4 + 160 + 16 + (cap + 18) + 16 + 4 = 228.
@MainActor
final class MediaCardListFigmaAlignmentTests: XCTestCase {
    private static let titles = [
        "Guláš á la Kukučka s kváskovým chlebom Ďuro Truľo",
        "MINIT PINSA - Kvalita, ktorá sa stretáva s dokonalou chuťou",
    ]

    func testMetricsMatchFigma() {
        XCTAssertEqual(DSMediaCardList.cardSize, CGSize(width: 280, height: 228))
        XCTAssertEqual(DSMediaCardList.imageHeight, 160)
        XCTAssertEqual(DSMediaCardList.imageMargin, 4)
        XCTAssertEqual(DSMediaCardList.cornerRadius, 16)
        XCTAssertEqual(DSMediaCardList.imageCornerRadius, 12)
        XCTAssertEqual(DSMediaCardList.imageToTitleSpacing, 16)
        XCTAssertEqual(DSMediaCardList.titleHorizontalPadding, 20)
        XCTAssertEqual(DSMediaCardList.titleFollowingGap, 20)
        XCTAssertEqual(DSMediaCardList.itemSpacing, 8)
        XCTAssertEqual(DSMediaCardList.headerSpacing, 12)
        // The shared card radius stays 20; only these cards use 16.
        XCTAssertEqual(DSRadius.card, 20)
    }

    func testTitleStyleMatchesFigmaHeadingH4() {
        XCTAssertEqual(DSMediaCardList.titleStyle, .headingH4)
        XCTAssertEqual(DSMediaCardList.titleStyle.tracking, 0)
        XCTAssertNil(DSMediaCardList.titleStyle.figmaLineBox)
        XCTAssertEqual(DSMediaCardList.titlePointSize, 14)
        XCTAssertEqual(DSMediaCardList.titleLineSpacing, 4)
        let font = SharpGroteskFontMetrics.uiFont(pointSize: DSMediaCardList.titlePointSize)
        XCTAssertEqual(font.fontName, "SharpGroteskSmBold20-Regular")
        XCTAssertEqual(font.pointSize, 14)
    }

    /// At the default size each two-line card is exactly Figma's 228: the photo block (180),
    /// the trimmed title (cap + 18) and 20 under the last baseline.
    func testTwoLineCardsAre228TallAtTheDefaultSize() {
        // Cap height from the font file, not from the production trim constant.
        let cap = SharpGroteskFontMetrics.uiFont(pointSize: 14).capHeight
        XCTAssertEqual(cap, 10.04, accuracy: 0.05)
        for title in Self.titles {
            let height = Self.cardHeight(title, size: .large)
            XCTAssertEqual(height, 4 + 160 + 16 + cap + 18 + 20, accuracy: 0.75, title)
            XCTAssertEqual(height, 228, accuracy: 0.75, title)
        }
    }

    /// At a large Dynamic Type size the two title lines no longer fit in 228. The card grows
    /// so both lines stay inside it, with the same 20 under the last baseline.
    func testCardGrowsAtLargeDynamicTypeSoBothTitleLinesFit() {
        for title in Self.titles {
            let height = Self.cardHeight(title, size: .accessibility2)
            let titleBox = Self.titleBoxHeight(title, size: .accessibility2)
            XCTAssertGreaterThan(height, 228 + 10, title)
            XCTAssertEqual(height, 4 + 160 + 16 + titleBox + 20, accuracy: 0.75, title)
        }
    }

    private static func cardHeight(_ title: String, size: DynamicTypeSize) -> CGFloat {
        let item = DSMediaCardList.Item(id: 0, image: .mockRecipe1, title: title)
        let host = UIHostingController(rootView: DSMediaCard(item: item).environment(\.dynamicTypeSize, size))
        return host.sizeThatFits(in: CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude)).height
    }

    /// The trimmed two-line title box at `size`, measured on its own.
    private static func titleBoxHeight(_ title: String, size: DynamicTypeSize) -> CGFloat {
        let spacing = UIFontMetrics(forTextStyle: .body).scaledValue(
            for: DSMediaCardList.titleLineSpacing,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .accessibilityLarge)
        )
        let view = SharpGroteskCapTrim(followingGap: DSMediaCardList.titleFollowingGap) {
            Text(title)
                .typography(DSMediaCardList.titleStyle)
                .lineSpacing(spacing)
                .lineLimit(size > .large ? nil : 2)
                .multilineTextAlignment(.leading)
        }
        let width = DSMediaCardList.cardSize.width - DSMediaCardList.titleHorizontalPadding * 2
        let host = UIHostingController(
            rootView: view.frame(width: width, alignment: .leading).environment(\.dynamicTypeSize, size)
        )
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }
}
