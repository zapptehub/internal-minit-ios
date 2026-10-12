import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// The loading disc and its glyph stay one fixed-size component at every
/// content size: 48pt disc, glyph centred on it, neither grown by Dynamic Type.
@MainActor
final class ProgressDiscCenteringTests: XCTestCase {
    func testDiscAndGlyphStayFixedAndConcentric() throws {
        let sizes: [DynamicTypeSize] = [.large, .accessibility2, .accessibility5]
        var samples: [(DynamicTypeSize, Box, Box)] = []
        for size in sizes {
            let raster = try Self.render(
                DSProgressView().padding(40).background(Color.white),
                size: CGSize(width: 160, height: 160),
                dynamicType: size
            )
            let disc = try XCTUnwrap(
                raster.bbox { r, g, b in
                    abs(Int(r) - 237) < 14 && abs(Int(g) - 237) < 14 && abs(Int(b) - 237) < 14 && abs(Int(r) - Int(g)) < 8
                },
                "missing disc at \(size)"
            )
            let glyph = try XCTUnwrap(
                raster.bbox { r, g, b in
                    r < 50 && g < 50 && b < 50 && abs(Int(r) - Int(g)) < 18 && abs(Int(g) - Int(b)) < 18
                },
                "missing glyph at \(size)"
            )
            XCTAssertEqual(disc.width, 48, accuracy: 2, "disc scaled at \(size)")
            XCTAssertEqual(disc.height, 48, accuracy: 2, "disc scaled at \(size)")
            XCTAssertEqual(glyph.midX, disc.midX, accuracy: 1.5, "glyph off-centre horizontally at \(size)")
            XCTAssertEqual(glyph.midY, disc.midY, accuracy: 1.5, "glyph off-centre vertically at \(size)")
            XCTAssertLessThan(glyph.width, disc.width - 8)
            XCTAssertLessThan(glyph.height, disc.height - 8)
            samples.append((size, disc, glyph))
        }
        let large = try XCTUnwrap(samples.first { $0.0 == .large })
        for sample in samples where sample.0 != .large {
            XCTAssertEqual(sample.1.width, large.1.width, accuracy: 1, "\(sample.0) disc width")
            XCTAssertEqual(sample.1.height, large.1.height, accuracy: 1, "\(sample.0) disc height")
            XCTAssertEqual(sample.2.width, large.2.width, accuracy: 2, "\(sample.0) glyph width")
            XCTAssertEqual(sample.2.height, large.2.height, accuracy: 2, "\(sample.0) glyph height")
        }
    }

    static func render<V: View>(
        _ view: V,
        size: CGSize,
        dynamicType: DynamicTypeSize
    ) throws -> Raster {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, dynamicType))
        host.safeAreaRegions = []
        host.traitOverrides.preferredContentSizeCategory = dynamicType.uiContentSizeCategory
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = .light
        window.rootViewController = host
        host.view.frame = window.bounds
        host.view.backgroundColor = .white
        window.makeKeyAndVisible()
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.45))
        let width = Int(size.width)
        let height = Int(size.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            host.view.layer.render(in: context)
            return true
        }
        window.isHidden = true
        XCTAssertTrue(drew)
        return Raster(width: width, height: height, bytes: pixels)
    }

    struct Box {
        var minX: Int
        var minY: Int
        var maxX: Int
        var maxY: Int
        var width: CGFloat { CGFloat(maxX - minX + 1) }
        var height: CGFloat { CGFloat(maxY - minY + 1) }
        var midX: CGFloat { CGFloat(minX + maxX) / 2 }
        var midY: CGFloat { CGFloat(minY + maxY) / 2 }
    }

    struct Raster {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        func bbox(_ match: (UInt8, UInt8, UInt8) -> Bool) -> Box? {
            var minX = width, minY = height, maxX = -1, maxY = -1
            for y in 0..<height {
                for x in 0..<width {
                    let i = (y * width + x) * 4
                    if match(bytes[i], bytes[i + 1], bytes[i + 2]) {
                        minX = min(minX, x)
                        maxX = max(maxX, x)
                        minY = min(minY, y)
                        maxY = max(maxY, y)
                    }
                }
            }
            guard maxX >= 0 else { return nil }
            return Box(minX: minX, minY: minY, maxX: maxX, maxY: maxY)
        }
    }
}
