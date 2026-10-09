import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Figma "AMP / My Card" (6078:4684): black 32% scrim (OVERLAY 6078:4893) and a card
/// with a continuous 27 corner radius (Wrapper-Account 6078:4896).
@MainActor
final class LoyaltyCardDetailPopupTests: XCTestCase {
    func testScrimAndCornerRadiusMatchFigma() {
        XCTAssertEqual(DSPopupMetrics.scrimOpacity, 0.32)
        XCTAssertEqual(LoyaltyCardDetailView.cornerRadius, 27)
        // Card-local: the shared card radius stays 20.
        XCTAssertEqual(DSRadius.card, 20)
        XCTAssertEqual(DSConstant.cardCornerRadius.value, 20)
    }

    /// White content under the popup is dimmed to 255 × (1 − 0.32) ≈ 173 (0.4 gave 153).
    func testScrimDimsWhiteToThirtyTwoPercentBlack() throws {
        let image = try Self.render(
            Color.white
                .dsPopup(isPresented: .constant(true)) {
                    Color.white.frame(width: 100, height: 100)
                },
            size: CGSize(width: 300, height: 400)
        )
        XCTAssertEqual(Self.grey(image, x: 10, y: 10), 255 * (1 - 0.32), accuracy: 3, "scrim corner")
        XCTAssertEqual(Self.grey(image, x: 150, y: 200), 255, accuracy: 1, "card stays white")
    }

    /// On black, the card's top-left 40×40 corner matches a white continuous 27 rounded
    /// rectangle drawn at the same place, and differs clearly from a 20 one. The card's
    /// edge midpoints stay white, so the clip follows the full card shape.
    func testCardCornerIsContinuousTwentySeven() throws {
        let size = CGSize(width: 402, height: 520)
        func layout<V: View>(_ card: V) -> some View {
            card
                .padding(.horizontal, 20)
                .frame(width: size.width, height: size.height)
                .background(Color.black)
        }
        func reference(_ radius: CGFloat) -> some View {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color.white)
                .frame(height: 402)
        }
        let card = try Self.render(layout(LoyaltyCardDetailView(onClose: {})), size: size)
        let r27 = try Self.render(layout(reference(27)), size: size)
        let r20 = try Self.render(layout(reference(20)), size: size)
        // Card: x 20...382, height 402 centred in 520 → y 59...461.
        let top = 59, left = 20
        func cornerDifference(_ a: Bitmap, _ b: Bitmap) -> Double {
            var total = 0.0
            for y in top..<(top + 40) {
                for x in left..<(left + 40) {
                    total += abs(Self.grey(a, x: x, y: y) - Self.grey(b, x: x, y: y))
                }
            }
            return total / 1600
        }
        let to27 = cornerDifference(card, r27)
        let to20 = cornerDifference(card, r20)
        XCTAssertLessThan(to27, 2, "card corner matches a continuous 27 (mean grey difference \(to27))")
        XCTAssertGreaterThan(to20, 3 * max(to27, 1), "and not a 20 (\(to20) vs \(to27))")
        XCTAssertGreaterThan(Self.grey(card, x: left + 2, y: top + 201), 230, "left edge midpoint")
        XCTAssertGreaterThan(Self.grey(card, x: 201, y: top + 2), 230, "top edge midpoint")
        XCTAssertLessThan(Self.grey(card, x: left + 1, y: top + 1), 40, "corner pixel is outside")
    }

    /// Figma title 6078:5066 is Sharp Grotesk 32 with −1 tracking; the button label
    /// 6078:5103 is Body/Bold/md (system bold 16, line height 20). The label override is
    /// popup-only: a default `.social` `.large` button still uses `uiLargeBold`, and the
    /// popup button is `.regular`, 56 tall like Figma, while `.large` stays 48.
    func testFontsMatchFigma() {
        XCTAssertEqual(LoyaltyCardDetailView.titleStyle, .headingPopupTitle)
        XCTAssertEqual(FontType.headingPopupTitle.tracking, -1)
        XCTAssertNil(FontType.headingPopupTitle.figmaLineBox, "trimmed by SharpGroteskCapTrim instead")

        XCTAssertEqual(LoyaltyCardDetailView.closeLabelStyle, .bodyBoldMedium)
        XCTAssertEqual(FontType.bodyBoldMedium.tracking, 0)
        XCTAssertEqual(FontType.bodyBoldMedium.figmaLineBox?.lineHeight, 20)
        XCTAssertEqual(
            FontType.bodyBoldMedium.figmaLineBox?.naturalLineHeight,
            UIFont.systemFont(ofSize: 16, weight: .bold).lineHeight
        )

        let popupButton = DSButton(title: "Close", type: .social, heightStyle: .large, labelStyle: .bodyBoldMedium) {}
        XCTAssertEqual(popupButton.labelFont, .bodyBoldMedium)
        let sharedButton = DSButton(title: "Apple", type: .social, heightStyle: .large) {}
        XCTAssertEqual(sharedButton.labelFont, .uiLargeBold, "shared default unchanged")
        XCTAssertEqual(LoyaltyCardDetailView.closeButtonHeightStyle.value, 56, "Figma button 56")
        XCTAssertEqual(DSButtonHeightStyle.regular.value, 56, "shared sizes unchanged")
        XCTAssertEqual(DSButtonHeightStyle.large.value, 48, "shared sizes unchanged")
    }

    /// The title alone, top-aligned: with the cap trim its ink starts at the top of its
    /// box (no line-box gap above the cap), and the ink spans cap + descender of a 32pt
    /// face ("y" in "My loyalty card"), about 23 + 7. At the old 20pt it was about 18.
    func testTitleIsCapTrimmedThirtyTwo() throws {
        let size = CGSize(width: 402, height: 120)
        let image = try Self.render(
            VStack(spacing: 0) {
                SharpGroteskCapTrim(followingGap: DSConstant.large.value) {
                    Text("My loyalty card")
                        .typography(LoyaltyCardDetailView.titleStyle)
                        .foregroundColor(DSColor.Text.heading)
                }
                Spacer(minLength: 0)
            }
            .frame(width: size.width, height: size.height),
            size: size
        )
        var inkRows: [Int] = []
        for y in 0..<Int(size.height) where (0..<Int(size.width)).contains(where: { Self.grey(image, x: $0, y: y) < 120 }) {
            inkRows.append(y)
        }
        let first = try XCTUnwrap(inkRows.first), last = try XCTUnwrap(inkRows.last)
        XCTAssertLessThanOrEqual(first, 1, "cap top at the top of the trimmed box")
        XCTAssertEqual(Double(last - first + 1), 30, accuracy: 3, "32pt cap + descender ink height")
    }

    /// Figma 6078:4896: padding 40/24/24, gap 32, effect "Extra Large", min height 402.
    func testLayoutMetricsMatchFigma() {
        XCTAssertEqual(LoyaltyCardDetailView.contentPaddingTop, 40)
        XCTAssertEqual(LoyaltyCardDetailView.contentPaddingHorizontal, 24)
        XCTAssertEqual(LoyaltyCardDetailView.contentPaddingBottom, 24)
        XCTAssertEqual(LoyaltyCardDetailView.contentSpacing, 32)
        XCTAssertEqual(LoyaltyCardDetailView.cardHeight, 402)
        // Wiring guard, not a token check: `shadow` is currently an alias of `.extraLarge`,
        // so this only fails if the popup is switched to another shadow token. The token
        // values themselves are pinned in testExtraLargeShadowTokenMatchesFigma.
        ChallengesCardListHeightTests.assertSameShadow(LoyaltyCardDetailView.shadow, DSShadow.extraLarge)
    }

    func testExtraLargeShadowTokenMatchesFigma() {
        let token = DSShadow.extraLarge
        XCTAssertEqual(ChallengesCardListHeightTests.rgba(token.near.color), [0x3E, 0x34, 0x45, 0x0A])
        XCTAssertEqual(token.near.radius, 2)
        XCTAssertEqual(token.near.x, 0)
        XCTAssertEqual(token.near.y, 2)
        XCTAssertEqual(ChallengesCardListHeightTests.rgba(token.far.color), [0x3E, 0x34, 0x45, 0x2E])
        XCTAssertEqual(token.far.radius, 56)
        XCTAssertEqual(token.far.x, 0)
        XCTAssertEqual(token.far.y, 56)
        XCTAssertEqual(token.farCasterInset, 20)
        // The shared card shadow is unchanged.
        XCTAssertEqual(DSShadow.card.radius, 16)
        XCTAssertEqual(DSShadow.card.y, 8)
    }

    /// Rendered top-aligned on black: the title's cap starts 40 below the card top, the
    /// QR code 32 below the title's baseline box (40 + 23 + 32 = 95), the 56 button 32
    /// below the QR code (95 + 195 + 32 = 322), and the card is the 402 minimum.
    func testContentIsTopAlignedWithFigmaPaddingAndGaps() throws {
        let size = CGSize(width: 362, height: 480)
        let image = try Self.render(
            LoyaltyCardDetailView(title: "My loyalty card", closeLabel: "Close", onClose: {})
                .frame(width: size.width, height: size.height, alignment: .top)
                .background(Color.black),
            size: size
        )
        let mid = 181
        let whiteRows = (0..<Int(size.height)).filter { Self.grey(image, x: mid, y: $0) > 30 }
        XCTAssertEqual(Double(try XCTUnwrap(whiteRows.last)) + 1, 402, accuracy: 1, "card height")

        let titleInk = (0..<90).filter { y in (40..<322).contains { Self.grey(image, x: $0, y: y) < 120 } }
        XCTAssertEqual(Double(try XCTUnwrap(titleInk.first)), 40, accuracy: 1.5, "title cap top")

        // QR: 195 wide around the centre column starting at x 83; its finder pattern is dark.
        let qrInk = (90..<300).filter { y in (84..<278).contains { Self.grey(image, x: $0, y: y) < 160 } }
        XCTAssertEqual(Double(try XCTUnwrap(qrInk.first)), 95, accuracy: 6, "QR top (finder ring anti-aliasing)")

        // Button: #F2F2F2 at x 100, clear of the pill's rounded ends and the label.
        let buttonRows = (280..<420).filter { (236...246).contains(Self.grey(image, x: 100, y: $0)) }
        let buttonTop = try XCTUnwrap(buttonRows.first), buttonBottom = try XCTUnwrap(buttonRows.last)
        XCTAssertEqual(Double(buttonTop), 322, accuracy: 2, "button top")
        XCTAssertEqual(Double(buttonBottom - buttonTop + 1), 56, accuracy: 2, "button 56")
        // Content adds up to 402: only the 24 bottom padding is under the button.
        XCTAssertEqual(Double(402 - (buttonBottom + 1)), 24, accuracy: 2, "nothing left over under the button")
    }

    /// Below the card, the far "Extra Large" shadow (y 56, blur 112, 18%) darkens the white
    /// page clearly; the old `dsCardShadow` (y 8, radius 16, 12% black) left it near white.
    func testExtraLargeShadowDarkensBelowCard() throws {
        let size = CGSize(width: 402, height: 620)
        let image = try Self.render(
            LoyaltyCardDetailView(title: "My loyalty card", closeLabel: "Close", onClose: {})
                .padding(.horizontal, 20)
                .padding(.top, 40)
                .frame(width: size.width, height: size.height, alignment: .top),
            size: size
        )
        let below = Self.grey(image, x: 201, y: 40 + 402 + 40)
        XCTAssertLessThan(below, 248, "far shadow 40 below the card")
        XCTAssertGreaterThan(below, 200, "soft, not a hard edge")
        XCTAssertGreaterThan(Self.grey(image, x: 201, y: 20), 250, "almost nothing above the card")
    }

    /// iPhone 16 Pro / 17 Pro screen (402×874) with real-world safe areas (62 top, 34
    /// bottom) and a 83 tab bar inside the hosted content. Under `.dsPopupHost()` the
    /// popup ignores the safe areas: the card's top is Figma's y 236 ((874 − 402) / 2) and
    /// the scrim also dims the tab bar.
    func testHostedPopupIsCentredOnFullScreenAndCoversTabBar() throws {
        let size = CGSize(width: 402, height: 874)
        let image = try Self.render(
            // Safe areas come from outside the host, like the window's around the TabView.
            Self.fakeTabScreen(popupPresented: true)
                .dsPopupHost()
                .safeAreaPadding(.top, 62)
                .safeAreaPadding(.bottom, 34),
            size: size,
            settle: 1.5
        )
        XCTAssertEqual(Double(Self.cardTop(image)), 236, accuracy: 1.5, "card top on the full screen")
        // The white tab bar (bottom 83) is under the scrim: 255 × 0.68 ≈ 173.
        XCTAssertEqual(Self.grey(image, x: 30, y: 860), 255 * 0.68, accuracy: 3, "tab bar dimmed")
        XCTAssertEqual(Self.grey(image, x: 30, y: 10), 255 * 0.68, accuracy: 3, "status bar area dimmed")
    }

    /// Without a host, `dsPopup` still ignores safe areas and centres on its view's full
    /// bounds (the fallback for screens outside the tab root).
    func testUnhostedPopupCentresOnFullBounds() throws {
        let size = CGSize(width: 402, height: 874)
        let image = try Self.render(
            Color.white
                .dsPopup(isPresented: .constant(true)) {
                    LoyaltyCardDetailView(title: "My loyalty card", closeLabel: "Close", onClose: {})
                }
                .safeAreaPadding(.top, 62)
                .safeAreaPadding(.bottom, 34),
            size: size
        )
        XCTAssertEqual(Double(Self.cardTop(image)), 236, accuracy: 1.5)
    }

    /// The host presents, a scrim tap asks the presenter to close (its binding), and only
    /// the owning `dsPopup` can clear the popup.
    func testHostPresentDismissAndClear() {
        let host = DSPopupHostModel()
        let owner = UUID(), other = UUID()
        var dismissed = false
        host.present(AnyView(Color.white), horizontalPadding: 20, ownerID: owner) { dismissed = true }
        XCTAssertNotNil(host.content)
        host.dismiss()
        XCTAssertTrue(dismissed, "scrim tap reaches the presenter")

        // A locked presenter (logging out): the scrim tap does nothing.
        var lockedDismissed = false
        host.present(AnyView(Color.white), horizontalPadding: 20, isEnabled: false, ownerID: owner) {
            lockedDismissed = true
        }
        XCTAssertFalse(host.isContentEnabled)
        host.dismiss()
        XCTAssertFalse(lockedDismissed, "no dismiss while locked")
        host.present(AnyView(Color.white), horizontalPadding: 20, isEnabled: true, ownerID: owner) {
            lockedDismissed = true
        }
        host.dismiss()
        XCTAssertTrue(lockedDismissed, "dismiss works again once unlocked")
        host.clear(ownerID: other)
        XCTAssertNotNil(host.content, "another popup can't clear it")
        host.clear(ownerID: owner)
        XCTAssertNil(host.content)
    }

    /// Closing via the binding (Close button) removes the hosted popup.
    func testHostedPopupClosesWhenBindingTurnsFalse() throws {
        let size = CGSize(width: 402, height: 874)
        let closed = try Self.render(
            Self.fakeTabScreen(popupPresented: false).dsPopupHost(),
            size: size
        )
        XCTAssertEqual(Self.grey(closed, x: 30, y: 860), 255, accuracy: 1, "no scrim when closed")
    }

    /// Mirrors Android `loggingOutIgnoresDismiss`. `HomeScreen` applies
    /// `.disabled(isLoggingOut)` after `.dsPopup`, so while logging out the popup's Close
    /// button (and scrim) must be disabled. The probe stands in for the popup content: it
    /// draws black while enabled, white while disabled.
    ///
    /// The hosted popup is drawn by `.dsPopupHost()` on the TabView, outside Home's subtree,
    /// so `dsPopup` passes the presenter's `isEnabled` to the host (9.10 review 2 blocker 1).
    func testLoggingOutDisablesHostedPopup() throws {
        let image = try Self.render(
            Self.loggingOutHome(hosted: true),
            size: CGSize(width: 402, height: 874),
            settle: 1.5
        )
        XCTAssertEqual(Self.grey(image, x: 201, y: 437), 255, accuracy: 1, "popup content disabled while logging out")
    }

    /// Control for the test above: without a host the popup is inside Home's subtree and
    /// inherits `.disabled(isLoggingOut)`, so the probe reads disabled.
    func testLoggingOutDisablesUnhostedPopup() throws {
        let image = try Self.render(
            Self.loggingOutHome(hosted: false),
            size: CGSize(width: 402, height: 874)
        )
        XCTAssertEqual(Self.grey(image, x: 201, y: 437), 255, accuracy: 1, "popup content disabled while logging out")
    }

    /// Home-like screen while logging out: `.dsPopup` then `.disabled(true)`, like `HomeScreen`.
    @ViewBuilder
    private static func loggingOutHome(hosted: Bool) -> some View {
        let home = Color.white
            .dsPopup(isPresented: .constant(true)) { EnabledProbe() }
            .disabled(true)
            .ignoresSafeArea()
        if hosted {
            home.dsPopupHost()
        } else {
            home
        }
    }

    /// Black while `isEnabled`, white while disabled.
    private struct EnabledProbe: View {
        @Environment(\.isEnabled) private var isEnabled
        var body: some View {
            (isEnabled ? Color.black : Color.white).frame(width: 100, height: 100)
        }
    }

    /// White page with a white 83-tall "tab bar" at the bottom of its full bounds, the
    /// popup presented from inside like Home inside the `TabView`.
    private static func fakeTabScreen(popupPresented: Bool) -> some View {
        VStack(spacing: 0) {
            Color.white
                .dsPopup(isPresented: .constant(popupPresented)) {
                    LoyaltyCardDetailView(title: "My loyalty card", closeLabel: "Close", onClose: {})
                }
            Color.white.frame(height: 83)
        }
        .ignoresSafeArea()
    }

    /// First row at the centre column, below the dimmed top, that is the white card.
    private static func cardTop(_ image: Bitmap) -> Int {
        (0..<image.height).first { grey(image, x: image.width / 2, y: $0) > 240 } ?? -1
    }

    // MARK: Helpers

    private static func render<V: View>(_ view: V, size: CGSize, settle: TimeInterval = 0.5) throws -> Bitmap {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, .large))
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        host.view.frame = window.bounds
        host.view.backgroundColor = .white
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(settle))
        // A hosted popup is presented from `onAppear`; lay out again once it's in.
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let width = Int(size.width), height = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            // The layer tree renders bottom row first (Core Graphics order).
            host.view.layer.render(in: context)
            return true
        }
        window.isHidden = true
        XCTAssertTrue(drawn)
        return Bitmap(width: width, height: height, bytes: bytes)
    }

    struct Bitmap {
        let width: Int
        let height: Int
        let bytes: [UInt8]
    }

    private static func grey(_ image: Bitmap, x: Int, y: Int) -> Double {
        let i = ((image.height - 1 - y) * image.width + x) * 4
        return (Double(image.bytes[i]) + Double(image.bytes[i + 1]) + Double(image.bytes[i + 2])) / 3
    }
}
