import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Rendered gaps on `LoyaltyCard`. The cap trim used to remove Sharp Grotesk's
/// line gap even though SwiftUI's line box does not include it, so these
/// collapsed to ~3pt (title → subtitle) and ~5pt (points baseline → chip).
final class LoyaltyCardSpacingTests: XCTestCase {
    @MainActor
    func testDefaultContentSizeGapsMatchFigma() throws {
        let card = try Self.renderCard(dynamicType: .large)
        let gaps = try Self.measureGaps(card)

        let subtitleBearing = try Self.subtitleInkTop()
        let expectedTitleGap = LoyaltyCardMetrics.rankSubtitleSpacing + subtitleBearing

        XCTAssertEqual(
            gaps.titleCapBottomToSubtitleTop,
            expectedTitleGap,
            accuracy: 1.5,
            "title→subtitle ink \(gaps.titleCapBottomToSubtitleTop)pt, expected \(expectedTitleGap)pt (6pt box gap + \(subtitleBearing)pt subtitle bearing). \(gaps)"
        )
        XCTAssertEqual(
            gaps.pointsBaselineToChipTop,
            LoyaltyCardMetrics.sectionSpacing,
            accuracy: 1.5,
            "points baseline→chip \(gaps.pointsBaselineToChipTop)pt, expected 20pt. \(gaps)"
        )
        XCTAssertGreaterThan(
            gaps.commaBottomToChipTop,
            4,
            "comma runs into the chip (\(gaps.commaBottomToChipTop)pt). \(gaps)"
        )
        XCTAssertEqual(gaps.cardHeight, 200, accuracy: 4, "\(gaps)")
    }

    /// "Silver" fits on one line at the default size, so the card matches a
    /// one-letter rank. At accessibility sizes the word is fitted to the
    /// column instead of splitting mid-word, and the card still grows.
    @MainActor
    func testRankTitleWrapsAtAccessibilitySizesAndStaysOneLineAtDefault() {
        let silverLarge = Self.cardHeight(rank: "Silver", dynamicType: .large)
        let shortLarge = Self.cardHeight(rank: "A", dynamicType: .large)
        XCTAssertEqual(silverLarge, shortLarge, accuracy: 1)
        XCTAssertEqual(silverLarge, 200, accuracy: 4)

        let silverAX = Self.cardHeight(rank: "Silver", dynamicType: .accessibility5)
        let shortAX = Self.cardHeight(rank: "A", dynamicType: .accessibility5)
        XCTAssertEqual(silverAX, shortAX, accuracy: 16)
        XCTAssertGreaterThan(silverAX, silverLarge + 40)
    }

    /// The line box SwiftUI lays out is `ascender − descender`. Including `leading`
    /// in the bottom trim (the previous bug) shortens a 56pt line from the cap
    /// height (~40pt) to ~25pt.
    @MainActor
    func testCapTrimUsesTheResolvedLineBoxNotTheFontLeading() {
        let font = SharpGroteskFontMetrics.uiFont(pointSize: LoyaltyCardMetrics.pointsFontSize)
        XCTAssertEqual(font.ascender, 44.8, accuracy: 0.05)
        XCTAssertEqual(font.descender, -11.2, accuracy: 0.05)
        XCTAssertEqual(font.leading, 15.4, accuracy: 0.05)
        XCTAssertEqual(font.capHeight, 40.152, accuracy: 0.05)
        XCTAssertEqual(font.lineHeight, font.ascender - font.descender, accuracy: 0.05)
        XCTAssertEqual(
            font.capHeight / font.ascender,
            SharpGroteskFontMetrics.capHeightPerAscender,
            accuracy: 0.0001
        )

        let plain = Self.measureLine(
            Text("1,410").typography(LoyaltyCardMetrics.pointsStyle)
        )
        let trimmed = Self.measureLine(
            SharpGroteskCapTrim(followingGap: LoyaltyCardMetrics.sectionSpacing) {
                Text("1,410").typography(LoyaltyCardMetrics.pointsStyle)
            }
        )
        let cap = plain.baseline * SharpGroteskFontMetrics.capHeightPerAscender
        let brokenBottomInset = -font.descender + font.leading
        let brokenHeight = plain.height - (font.ascender - font.capHeight) - brokenBottomInset

        XCTAssertEqual(brokenHeight, 25, accuracy: 1.5, "old trim height \(brokenHeight)")
        XCTAssertEqual(trimmed.height, cap, accuracy: 0.75, "trimmed \(trimmed) cap \(cap)")
        XCTAssertEqual(trimmed.baseline, cap, accuracy: 0.75, "baseline should sit on the cap-box bottom")
        XCTAssertGreaterThan(trimmed.height, brokenHeight + 10)

        let title = Self.measureLine(
            SharpGroteskCapTrim(followingGap: LoyaltyCardMetrics.rankSubtitleSpacing) {
                Text("Bronze").typography(LoyaltyCardMetrics.rankTitleStyle)
            }
        )
        let titlePlain = Self.measureLine(
            Text("Bronze").typography(LoyaltyCardMetrics.rankTitleStyle)
        )
        let titleCap = titlePlain.baseline * SharpGroteskFontMetrics.capHeightPerAscender
        XCTAssertEqual(title.height, titleCap, accuracy: 0.75)
        XCTAssertEqual(title.baseline, titleCap, accuracy: 0.75)
    }

    /// At accessibility sizes the resolved descent can exceed the 20pt / 6pt
    /// gaps. The trim grows the box so the next row starts at the descent.
    @MainActor
    func testAccessibilitySizesKeepDescendersOffTheNextRow() {
        let cases: [(DynamicTypeSize, CGFloat, FontType, String, CGFloat)] = [
            (.large, .infinity, .headingLargeBold, "1,410", LoyaltyCardMetrics.sectionSpacing),
            (.accessibility5, .infinity, .headingLargeBold, "1,410", LoyaltyCardMetrics.sectionSpacing),
            (.accessibility5, 193, .headingLargeBold, "1,410", LoyaltyCardMetrics.sectionSpacing),
            (.accessibility5, .infinity, .headingMediumBold, "Bronze", LoyaltyCardMetrics.rankSubtitleSpacing),
        ]
        for item in cases {
            let plain = Self.measureLine(
                Text(item.3)
                    .typography(item.2)
                    .lineLimit(1)
                    .frame(maxWidth: item.1)
                    .environment(\.dynamicTypeSize, item.0)
            )
            let trimmed = Self.measureLine(
                SharpGroteskCapTrim(followingGap: item.4) {
                    Text(item.3)
                        .typography(item.2)
                        .lineLimit(1)
                }
                .frame(maxWidth: item.1)
                .environment(\.dynamicTypeSize, item.0)
            )
            let belowBaseline = plain.height - plain.baseline
            let baselineToNextRow = (trimmed.height - trimmed.baseline) + item.4
            XCTAssertGreaterThanOrEqual(
                baselineToNextRow + 0.75,
                belowBaseline,
                "\(item.0) width \(item.1): descent \(belowBaseline) reaches the next row (clearance \(baselineToNextRow))"
            )
            let cap = plain.baseline * SharpGroteskFontMetrics.capHeightPerAscender
            XCTAssertGreaterThanOrEqual(trimmed.height + 0.75, cap)
        }
    }

    @MainActor
    static func measureLine<V: View>(_ view: V) -> (height: CGFloat, baseline: CGFloat) {
        let store = LineStore()
        let root = LineProbe(store: store) { view }
        let host = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        return (store.height, store.baseline)
    }

    @MainActor
    static func cardHeight(
        rank: String,
        dynamicType: DynamicTypeSize,
        width: CGFloat = 354
    ) -> CGFloat {
        let view = LoyaltyCard(
            rankTitle: rank,
            rankSubtitle: "540 pts until Platinum",
            points: 3210,
            chipLabel: "Minit Card",
            rankProgress: 0.75,
            showsShadow: false
        )
        .frame(width: width)
        .environment(\.dynamicTypeSize, dynamicType)
        return UIHostingController(rootView: view)
            .sizeThatFits(in: CGSize(width: width, height: 4000))
            .height
    }

    @MainActor
    static func renderCard(dynamicType: DynamicTypeSize, width: CGFloat = 354) throws -> UIImage {
        let view = LoyaltyCard(
            rankTitle: "Bronze",
            rankSubtitle: "Earn unique benefits",
            points: 1410,
            chipLabel: "Loyalty Card",
            rankProgress: 0.75,
            showsShadow: false
        )
        .frame(width: width)
        .environment(\.dynamicTypeSize, dynamicType)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let image = renderer.uiImage, image.cgImage != nil else {
            throw MeasureError.unrendered
        }
        return image
    }

    /// Distance from the top of the subtitle line box to the first ink pixel.
    @MainActor
    static func subtitleInkTop() throws -> CGFloat {
        let renderer = ImageRenderer(
            content: Text("Earn unique benefits")
                .typography(LoyaltyCardMetrics.subtitleStyle)
                .foregroundColor(LoyaltyCardMetrics.rankSubtitleColor)
                .fixedSize()
                .environment(\.dynamicTypeSize, .large)
        )
        renderer.scale = 3
        guard let image = renderer.uiImage else { throw MeasureError.unrendered }
        let pixels = try Pixels(image)
        for y in 0..<pixels.height {
            for x in 0..<pixels.width {
                if pixels.isSubtitle(x, y) {
                    return CGFloat(y) / pixels.scale
                }
            }
        }
        throw MeasureError.missingSubtitle
    }

    static func measureGaps(_ image: UIImage) throws -> Gaps {
        let pixels = try Pixels(image)
        let scale = pixels.scale

        let title = try pixels.brownBounds(
            x0: pixels.px(64),
            x1: pixels.px(180),
            y0: pixels.px(8),
            y1: pixels.px(70)
        )
        let subtitle = try pixels.subtitleBounds(
            x0: pixels.px(70),
            x1: pixels.px(250),
            y0: title.maxY + 1,
            y1: title.maxY + pixels.px(36)
        )
        let points = try pixels.columnBounds(
            x0: pixels.px(12),
            x1: pixels.px(170),
            y0: subtitle.maxY + pixels.px(8),
            y1: pixels.height
        )
        let chipTop = try pixels.chipTop(
            x0: pixels.px(30),
            x1: pixels.px(160),
            y0: points.baselineY
        )

        func pt(_ px: Int) -> CGFloat { CGFloat(px) / scale }
        return Gaps(
            cardHeight: image.size.height,
            titleCapBottomToSubtitleTop: pt(subtitle.minY - title.maxY),
            pointsBaselineToChipTop: pt(chipTop - points.baselineY),
            commaBottomToChipTop: pt(chipTop - points.maxY)
        )
    }
}

private final class LineStore {
    var height: CGFloat = -1
    var baseline: CGFloat = -1
}

private struct LineProbe<Content: View>: View {
    let store: LineStore
    @ViewBuilder var content: () -> Content

    var body: some View {
        LineProbeLayout(store: store) { content() }
    }
}

private struct LineProbeLayout: Layout {
    let store: LineStore

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        subviews[0].sizeThatFits(proposal)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let dims = subviews[0].dimensions(in: proposal)
        store.height = dims.height
        store.baseline = dims[VerticalAlignment.firstTextBaseline]
        subviews[0].place(at: bounds.origin, proposal: proposal)
    }
}

struct Gaps: CustomStringConvertible {
    var cardHeight: CGFloat
    var titleCapBottomToSubtitleTop: CGFloat
    var pointsBaselineToChipTop: CGFloat
    var commaBottomToChipTop: CGFloat

    var description: String {
        """
        card=\(cardHeight) titleToSubtitle=\(titleCapBottomToSubtitleTop) \
        baselineToChip=\(pointsBaselineToChipTop) commaToChip=\(commaBottomToChipTop)
        """
    }
}

enum MeasureError: Error {
    case unrendered
    case missingTitle
    case missingSubtitle
    case missingPoints
    case missingChip
}

struct Pixels {
    let width: Int
    let height: Int
    let scale: CGFloat
    private let bytes: [UInt8]

    init(_ image: UIImage) throws {
        guard let cg = image.cgImage else { throw MeasureError.unrendered }
        width = cg.width
        height = cg.height
        scale = image.scale
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &buffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        guard let context else { throw MeasureError.unrendered }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = buffer
    }

    func px(_ points: CGFloat) -> Int { Int((points * scale).rounded()) }

    func brownBounds(x0: Int, x1: Int, y0: Int, y1: Int) throws -> (minY: Int, maxY: Int) {
        var minY = height
        var maxY = -1
        for y in y0..<min(y1, height) {
            for x in x0..<min(x1, width) where isBrown(x, y) {
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxY >= 0 else { throw MeasureError.missingTitle }
        return (minY, maxY)
    }

    func subtitleBounds(x0: Int, x1: Int, y0: Int, y1: Int) throws -> (minY: Int, maxY: Int) {
        var minY = height
        var maxY = -1
        for y in y0..<min(y1, height) {
            for x in x0..<min(x1, width) where isSubtitle(x, y) {
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
        }
        guard maxY >= 0 else { throw MeasureError.missingSubtitle }
        return (minY, maxY)
    }

    /// Digit baseline is the most common column-bottom. The comma is the deeper tail.
    func columnBounds(x0: Int, x1: Int, y0: Int, y1: Int) throws -> (baselineY: Int, maxY: Int) {
        var bottoms: [Int] = []
        var maxY = -1
        for x in x0..<min(x1, width) {
            var columnBottom = -1
            for y in y0..<min(y1, height) where isBrown(x, y) {
                columnBottom = y
            }
            if columnBottom >= 0 {
                bottoms.append(columnBottom)
                maxY = max(maxY, columnBottom)
            }
        }
        guard !bottoms.isEmpty else { throw MeasureError.missingPoints }
        let histogram = Dictionary(grouping: bottoms, by: { $0 }).mapValues(\.count)
        guard let baseline = histogram.max(by: { $0.value < $1.value })?.key else {
            throw MeasureError.missingPoints
        }
        return (baseline, maxY)
    }

    func chipTop(x0: Int, x1: Int, y0: Int) throws -> Int {
        let start = min(width, x0)
        let end = min(width, x1)
        let step = 2
        var samples = 0
        var x = start
        while x < end {
            samples += 1
            x += step
        }
        guard samples > 0 else { throw MeasureError.missingChip }
        for y in y0..<height {
            var hits = 0
            var x = start
            while x < end {
                if isChip(x, y) { hits += 1 }
                x += step
            }
            if hits * 2 > samples { return y }
        }
        throw MeasureError.missingChip
    }

    func isBrown(_ x: Int, _ y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        return abs(Int(r) - 0x33) + abs(Int(g) - 0x1A) + abs(Int(b) - 0x00) < 40
    }

    func isSubtitle(_ x: Int, _ y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        let spread = max(r, g, b) - min(r, g, b)
        let average = (Int(r) + Int(g) + Int(b)) / 3
        return spread < 16 && average > 145 && average < 185
    }

    func isChip(_ x: Int, _ y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        let spread = Int(max(r, g, b) - min(r, g, b))
        let average = (Int(r) + Int(g) + Int(b)) / 3
        return spread < 20 && average > 190 && average < 250
    }

    private func rgb(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) {
        let o = (y * width + x) * 4
        return (bytes[o], bytes[o + 1], bytes[o + 2])
    }
}
