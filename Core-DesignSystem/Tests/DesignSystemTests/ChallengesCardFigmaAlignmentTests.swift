import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Remaining Figma alignment for the Home sections (file XDtLIOc3QdetbZ8h5Q7QVz):
/// Challenges 6143:1976, Products 6154:1940, News & Recipes 6154:2057.
@MainActor
final class ChallengesCardFigmaAlignmentTests: XCTestCase {
    // MARK: Pill (PTS 6143:1895)

    func testPillMetricsMatchFigma() {
        XCTAssertEqual(DSChallengesCardList.badgeHorizontalPadding, 4)
        XCTAssertEqual(DSChallengesCardList.badgeVerticalPadding, 2)
        XCTAssertEqual(DSChallengesCardList.badgeContentSpacing, 4)
        XCTAssertEqual(DSChallengesCardList.badgeIconSize, 16)
        XCTAssertEqual(DSChallengesCardList.badgeTextStyle, .bodyBoldLabel)
        XCTAssertEqual(DSChallengesCardList.badgeTextStyle.tracking, 0)
        XCTAssertEqual(DSChallengesCardList.badgeTextStyle.figmaLineBox?.lineHeight, 20)
    }

    /// Figma hugs the pill to 72 × 24 for "+45 pts" (4 + 16 + 4 + 44 + 4, 2 + 20 + 2).
    /// Figma sets the text in SF Pro Display; iOS picks SF Pro Text's wider optical size
    /// at 12pt, so the text is ~47 and the pill ~75 wide.
    func testPillIsFigmaSized() {
        let size = Self.measure(DSChallengesCardList.badge(text: "+45 pts"))
        print("PILL_SIZE ios \(size)")
        XCTAssertEqual(size.height, 24, accuracy: 0.5)
        XCTAssertEqual(size.width, 72, accuracy: 4)
    }

    // MARK: Ring, icon, card gap

    func testRingTrackMatchesFigma() {
        XCTAssertEqual(DSChallengesCardList.iconRingLineWidth, 3)
        XCTAssertEqual(DSChallengesCardList.iconRingTrackOpacity, 0.24)
    }

    func testCroissantIsTwentyFourAndLineIconsStayTwenty() {
        XCTAssertEqual(DSChallengesCardList.iconSize(for: .croissant), 24)
        XCTAssertEqual(DSChallengesCardList.iconSize(for: .qrScanLine), 20)
        XCTAssertEqual(DSChallengesCardList.iconSize(for: .coffeeCup), 20)
    }

    func testCardGapIsEight() {
        XCTAssertEqual(DSChallengesCardList.itemSpacing, 8)
    }

    // MARK: Section header and inset

    func testSectionInsetIsTwenty() {
        XCTAssertEqual(DSCollectionHeader.horizontalInset, 20)
    }

    func testSectionTitleIsSharpGrotesk18CapTrimmed() {
        XCTAssertEqual(DSCollectionHeader.titleStyle, .headingSection)
        XCTAssertEqual(DSCollectionHeader.titleStyle.tracking, 0)
        let font = SharpGroteskFontMetrics.uiFont(pointSize: 18)
        XCTAssertEqual(font.fontName, "SharpGroteskSmBold20-Regular")

        let title = Self.measure(
            SharpGroteskCapTrim(followingGap: DSCollectionHeader.titleFollowingGap) {
                Text("Challenges").typography(DSCollectionHeader.titleStyle)
            }
        )
        print("SECTION_TITLE ios box=\(title) cap=\(font.capHeight)")
        // Figma's trimmed title box is 13 tall (cap height of 18pt Sharp Grotesk).
        XCTAssertEqual(title.height, font.capHeight, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(DSCollectionHeader.titleFollowingGap, -font.descender)

        // The header row stays 24 (the see-all button), with 20pt insets.
        let header = Self.measure(DSCollectionHeader(title: "Challenges", onSeeAllTapped: {}), width: 402)
        XCTAssertEqual(header.height, 24, accuracy: 0.5)
    }

    private static func measure<V: View>(_ view: V, width: CGFloat? = nil) -> CGSize {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, .large))
        return host.sizeThatFits(
            in: CGSize(width: width ?? .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        )
    }
}
