import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Figma Challenge card (6143:1889) is 200 × 124. The card keeps its 16pt padding,
/// so the 40pt ring row and a two-line title must fit in 124 − 32 = 92pt.
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

    func testTwoLineTitlesFitWithoutTruncation() {
        let padding = DSConstant.mediumLarge.value
        let titleWidth = DSChallengesCardList.cardSize.width - padding * 2
        let available = DSChallengesCardList.cardSize.height - padding * 2 - DSChallengesCardList.iconCircleDiameter
        let cap = SharpGroteskFontMetrics.uiFont(pointSize: DSChallengesCardList.titlePointSize).capHeight
        for title in Self.titles {
            let limited = Self.titleBoxHeight(title, lineLimit: 2, width: titleWidth)
            let unlimited = Self.titleBoxHeight(title, lineLimit: nil, width: titleWidth)
            let ringToCap = available - limited
            print(
                "TITLE_FONT ios title='\(title)' box=\(limited) full=\(unlimited) cap=\(cap) "
                    + "available=\(available) ringToCap=\(ringToCap) baselineToBottom=\(padding)"
            )
            XCTAssertEqual(limited, unlimited, accuracy: 0.5, "\(title) is truncated")
            // Two lines: cap of the first + one 20pt baseline-to-baseline step.
            XCTAssertEqual(limited, cap + DSChallengesCardList.titleLineHeight, accuracy: 0.75, "\(title) box")
            XCTAssertLessThanOrEqual(limited, available, "\(title) does not fit")
            XCTAssertEqual(ringToCap, 21, accuracy: 0.75, "\(title) ring to cap")
        }
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
