import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Figma effect style "Small" on the Daily Offer banners (Home 6065:4747,
/// Notifications 6123:1697), drawn by `DSBannerCarousel` itself.
@MainActor
final class BannerCarouselShadowTests: XCTestCase {
    func testShadowTokensMatchFigmaSmall() {
        // The banners use the shared Figma "Small" token (values checked in
        // ChallengesCardListHeightTests.testShadowMatchesFigmaSmallEffect).
        ChallengesCardListHeightTests.assertSameShadow(DSBannerCarousel.shadow, DSShadow.small)
    }

    /// Renders a single-banner carousel on white with 60pt of room around it. The banner's
    /// own scroll view must not clip the shadow: the white below the banner is tinted the
    /// way Figma's is (grey about 240 at +6, 248 at +20, i.e. 15 and 7 below the white
    /// background), and above it stays near white. The checks are relative to the
    /// background with a range wide enough for renderer differences; with no shadow
    /// every darkening is 0 and they all fail.
    func testSingleBannerCastsTheFigmaShadowOutsideItsFrame() throws {
        let image = try Self.render(
            DSBannerCarousel(items: [.init(id: 0, backgroundColor: DSColor.Background.brown)])
                .frame(width: 362)
                .padding(60)
                .background(Color.white),
            size: CGSize(width: 482, height: 200)
        )
        // Banner frame: x 60...422, y 60...140. (4, 4) is plain background.
        let background = Self.grey(image, x: 4, y: 4)
        let below6 = background - Self.grey(image, x: 241, y: 146)
        let below20 = background - Self.grey(image, x: 241, y: 160)
        let above6 = background - Self.grey(image, x: 241, y: 54)
        let side = background - Self.grey(image, x: 57, y: 130)
        XCTAssertGreaterThan(background, 250, "white background")
        XCTAssertTrue((8...24).contains(below6), "shadow 6pt below the banner darkens \(below6), Figma 15")
        XCTAssertTrue((3...14).contains(below20), "shadow 20pt below the banner darkens \(below20), Figma 7")
        XCTAssertGreaterThan(below6, below20, "the shadow fades with distance")
        XCTAssertLessThan(above6, 4, "the shadow falls downwards")
        XCTAssertGreaterThan(side, 0, "the shadow reaches past the banner's sides")
    }

    func testMultiBannerCarouselDoesNotClipTheShadowBelow() throws {
        let image = try Self.render(
            DSBannerCarousel(items: [
                .init(id: 0, backgroundColor: DSColor.Background.brown),
                .init(id: 1, backgroundColor: DSColor.Background.pink),
            ])
            .frame(width: 402)
            .padding(.vertical, 60)
            .background(Color.white),
            size: CGSize(width: 402, height: 211)
        )
        // Active page: x 20...382, y 60...140; the indicator sits 8 below, at the centre.
        // Relative to the white background (4, 4), as in the single-banner test: Figma is
        // about 15 darker at +6 and 5 darker at +30. With the shadow clipped both are 0.
        let background = Self.grey(image, x: 4, y: 4)
        let below6 = background - Self.grey(image, x: 100, y: 146)
        let below30 = background - Self.grey(image, x: 100, y: 170)
        XCTAssertGreaterThan(background, 250, "white background")
        XCTAssertTrue((8...24).contains(below6), "shadow 6pt below the active banner darkens \(below6)")
        XCTAssertTrue((2...12).contains(below30), "shadow 30pt below the active banner darkens \(below30)")
        XCTAssertGreaterThan(below6, below30, "the shadow fades with distance")
    }

    /// Figma Home "Offers" (6065:4746): the active banner is 20 from each edge of a 402
    /// screen (x 20, width 362), 8 from its neighbours, which peek 12 in.
    func testMultiBannerInsetIsTwentyAndNeighboursPeekTwelve() throws {
        XCTAssertEqual(DSBannerCarousel.multiPageHorizontalInset, 20)
        XCTAssertEqual(DSBannerCarousel.itemSpacing, 8)
        let image = try Self.render(
            DSBannerCarousel(items: [
                .init(id: 0, backgroundColor: DSColor.Background.pink),
                .init(id: 1, backgroundColor: DSColor.Background.brown),
                .init(id: 2, backgroundColor: DSColor.Background.pink),
            ], initialIndex: 1)
            .frame(width: 402)
            .padding(.vertical, 60)
            .background(Color.white),
            size: CGSize(width: 402, height: 211)
        )
        let y = 100
        XCTAssertLessThan(Self.grey(image, x: 6, y: y), 230, "left neighbour peeks at x 0...12")
        XCTAssertGreaterThan(Self.grey(image, x: 16, y: y), 240, "8pt gap at x 12...20")
        XCTAssertLessThan(Self.grey(image, x: 21, y: y), 60, "active banner starts at x 20")
        XCTAssertGreaterThan(Self.grey(image, x: 18, y: y), 240, "nothing at x 16...20")
        XCTAssertLessThan(Self.grey(image, x: 380, y: y), 60, "active banner ends at x 382")
        XCTAssertGreaterThan(Self.grey(image, x: 384, y: y), 240, "8pt gap at x 382...390")
        XCTAssertLessThan(Self.grey(image, x: 396, y: y), 230, "right neighbour peeks at x 390...402")
    }

    // MARK: Helpers

    /// Hosts the view in a real window (the carousel is a UIKit-backed scroll view, which
    /// `ImageRenderer` does not draw) and renders its layer tree at 1x into RGBA bytes.
    private static func render<V: View>(_ view: V, size: CGSize) throws -> Bitmap {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, .large))
        // No safe area: the content sits at the window's top-left like a plain frame.
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = host
        host.view.frame = window.bounds
        host.view.backgroundColor = .white
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        let width = Int(size.width), height = Int(size.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            // `drawHierarchy` is unreliable without a window scene; the layer tree renders,
            // bottom row first in this bitmap (Core Graphics order).
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
