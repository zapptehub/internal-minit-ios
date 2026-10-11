import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Figma Challenge card (6143:1889): the "+N pts" pill is centred vertically on the
/// 40pt icon ring, not top-aligned.
@MainActor
final class ChallengesCardPillAlignmentTests: XCTestCase {
    func testTopRowAlignmentIsCenter() {
        XCTAssertEqual(DSChallengesCardList.topRowAlignment, .center)
    }

    /// Renders the real top-row layout with a 40pt "ring" and a 24pt "pill" placeholder
    /// and checks the pill's vertical centre equals the ring's.
    func testPillIsCentredOnTheRing() throws {
        let ring = DSChallengesCardList.iconCircleDiameter
        let pillHeight: CGFloat = 24
        let row = DSChallengesCardList.topRow {
            Color(red: 1, green: 0, blue: 0).frame(width: ring, height: ring)
        } trailing: {
            Color(red: 0, green: 0, blue: 1).frame(width: 72, height: pillHeight)
        }
        .frame(width: 168)
        .background(Color.white)

        let renderer = ImageRenderer(content: row)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let red = Self.rows(in: image) { r, g, b in r > 200 && g < 60 && b < 60 }
        let blue = Self.rows(in: image) { r, g, b in b > 200 && r < 80 && g < 80 }
        let ringRows = try XCTUnwrap(red)
        let pillRows = try XCTUnwrap(blue)
        let ringCentre = CGFloat(ringRows.lowerBound + ringRows.upperBound) / 2
        let pillCentre = CGFloat(pillRows.lowerBound + pillRows.upperBound) / 2
        XCTAssertEqual(CGFloat(ringRows.count), ring, accuracy: 1)
        XCTAssertEqual(CGFloat(pillRows.count), pillHeight, accuracy: 1)
        XCTAssertEqual(pillCentre, ringCentre, accuracy: 0.5)
        // Top-aligned would put the pill (40 − 24) / 2 = 8pt higher.
        XCTAssertGreaterThan(pillRows.lowerBound, ringRows.lowerBound + 6)
    }

    /// Rows (top inclusive, bottom exclusive) containing at least one matching pixel.
    private static func rows(in image: CGImage, match: (UInt8, UInt8, UInt8) -> Bool) -> Range<Int>? {
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
        guard drawn else { return nil }
        var first: Int?
        var last: Int?
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                if match(pixels[i], pixels[i + 1], pixels[i + 2]) {
                    if first == nil { first = y }
                    last = y
                    break
                }
            }
        }
        guard let first, let last else { return nil }
        return first..<(last + 1)
    }
}
