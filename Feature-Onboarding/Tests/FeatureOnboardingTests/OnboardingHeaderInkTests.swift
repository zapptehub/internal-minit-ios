import SwiftUI
import UIKit
import XCTest
import DesignSystem
@testable import FeatureOnboarding

/// Ink gaps on the processing-screen chrome: progress bar, header, and status card.
@MainActor
final class OnboardingHeaderInkTests: XCTestCase {
    func testProgressBarHeightIsThreePoints() {
        XCTAssertEqual(OnboardingProgressBar.height, 3)
    }

    func testProcessingChromeInkGapsMatchFigma() throws {
        let renderer = ImageRenderer(content: ProcessingChromeHarness().environment(\.dynamicTypeSize, .large))
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let pixels = try InkPixels(image)
        let measured = try pixels.measureProcessingChrome()
        print(
            "ONB_TYPO ios bar=\(measured.barHeight) gap1=\(measured.progressToHeaderInk) " +
            "gap2=\(measured.headerBaselineToHeadlineInk) gap3=\(measured.titleBaselineToSubtitleCap) " +
            "baselineToBaseline=\(measured.titleBaselineToSubtitleBaseline)"
        )
        let url = URL(fileURLWithPath: "/tmp/onb-typo-ios-processing.png")
        try? image.pngData()?.write(to: url)

        XCTAssertEqual(measured.barHeight, 3, accuracy: 1, "bar \(measured.barHeight)")
        XCTAssertEqual(measured.progressToHeaderInk, 21, accuracy: 1, "gap1 \(measured.progressToHeaderInk)")
        XCTAssertEqual(measured.headerBaselineToHeadlineInk, 16, accuracy: 1, "gap2 \(measured.headerBaselineToHeadlineInk)")
        XCTAssertEqual(measured.titleBaselineToSubtitleCap, 13.1, accuracy: 1, "gap3 \(measured.titleBaselineToSubtitleCap)")
        XCTAssertEqual(
            measured.titleBaselineToSubtitleBaseline,
            23,
            accuracy: 1,
            "baselines \(measured.titleBaselineToSubtitleBaseline)"
        )
    }

    func testTrackOpacityIsFigmaQuarterWhite() {
        XCTAssertEqual(OnboardingProgressBar.trackOpacity, 0.25, accuracy: 0)
        XCTAssertEqual(OnboardingProgressBar.height, 3)
    }

    func testScaffoldHeaderColorIsTextPrimary() {
        let header = colorChannels(OnboardingScaffoldHeader.color)
        let primary = colorChannels(DSColor.Text.primary)
        let heading = colorChannels(DSColor.Text.heading)
        XCTAssertEqual(header.r, primary.r)
        XCTAssertEqual(header.g, primary.g)
        XCTAssertEqual(header.b, primary.b)
        XCTAssertEqual(header.r, 0x1A)
        XCTAssertEqual(header.g, 0x1A)
        XCTAssertEqual(header.b, 0x1A)
        XCTAssertEqual(heading.r, 0x33)
        XCTAssertEqual(heading.g, 0x1A)
        XCTAssertEqual(heading.b, 0x00)
        XCTAssertNotEqual(header.r, heading.r)
    }

    func testRenderedTrackAndHeaderMatchFigma() throws {
        let renderer = ImageRenderer(
            content: ProcessingChromeHarness().environment(\.dynamicTypeSize, .large)
        )
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        try? image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/onb-color-ios-processing.png"))
        let pixels = try InkPixels(image)
        try pixels.assertFigmaTrackAndHeaderInk()
    }

    func testWritesNameStepScreenshot() throws {
        let renderer = ImageRenderer(
            content: NameChromeHarness().environment(\.dynamicTypeSize, .large)
        )
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        let url = URL(fileURLWithPath: "/tmp/onb-color-ios-name.png")
        try XCTUnwrap(image.pngData()).write(to: url)
        let hold = ProcessInfo.processInfo.environment["ONB_COLOR_HOLD_SECONDS"].flatMap(Double.init) ?? 0
        if hold > 0 {
            Thread.sleep(forTimeInterval: hold)
        }
    }
}

private struct ProcessingChromeHarness: View {
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(progress: 0.85)
                .padding(.top, DSConstant.medium.value)
                .padding(.horizontal, DSConstant.large.value)
            OnboardingScaffold(
                subtitle: "Every bite is a reward.",
                headline: "Finishing up your experience",
                primaryTitle: "Enter Minit",
                isPrimaryEnabled: false,
                onPrimary: {}
            ) {
                Color.clear
            }
            .overlay {
                DSStatusCard(
                    state: .loading(
                        title: "Processing loyalty card...",
                        subtitle: "This may take a second"
                    )
                )
                .padding(.horizontal, DSConstant.large.value)
            }
        }
        .frame(width: 402, height: 874)
        .background(LinearGradient.minitBackground)
    }
}

private struct NameChromeHarness: View {
    var body: some View {
        VStack(spacing: 0) {
            OnboardingProgressBar(progress: 0.16)
                .padding(.top, DSConstant.medium.value)
                .padding(.horizontal, DSConstant.large.value)
            OnboardingScaffold(
                subtitle: "Hello! Welcome to Minit",
                headline: "What is your name?",
                primaryTitle: "Continue",
                isPrimaryEnabled: false,
                onPrimary: {}
            ) {
                Text("Enter your name")
                    .font(.system(size: 30))
                    .foregroundColor(DSColor.Text.heading.opacity(0.4))
            }
        }
        .frame(width: 402, height: 874)
        .background(LinearGradient.minitBackground)
    }
}

private func colorChannels(_ color: Color) -> (r: Int, g: Int, b: Int) {
    let ui = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    precondition(
        ui.getRed(&red, green: &green, blue: &blue, alpha: &alpha),
        "could not read \(color)"
    )
    return (
        Int((red * 255).rounded()),
        Int((green * 255).rounded()),
        Int((blue * 255).rounded())
    )
}

private struct ProcessingMeasures {
    var barHeight: CGFloat
    var progressToHeaderInk: CGFloat
    var headerBaselineToHeadlineInk: CGFloat
    var titleBaselineToSubtitleCap: CGFloat
    var titleBaselineToSubtitleBaseline: CGFloat
}

private struct InkPixels {
    let width: Int
    let height: Int
    let scale: CGFloat
    private let bytes: [UInt8]

    init(_ image: UIImage) throws {
        guard let cg = image.cgImage else { throw InkError.unrendered }
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
        guard let context else { throw InkError.unrendered }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        bytes = buffer
    }

    func measureProcessingChrome() throws -> ProcessingMeasures {
        let bar = try barRows()
        let header = try inkBand(after: bar.last + 1, label: "header", matches: isHeaderInk)
        let headlineTop = try firstRow(after: header.inkBottom + 1, where: isWhiteInk, label: "headline")
        let title = try inkBand(after: headlineTop + 1, label: "title", matches: isBrownInk)
        let subtitleTop = try firstRow(after: title.baseline + 1, where: isGreyInk, label: "subtitle")
        let subtitleBaseline = try greyBaseline(after: title.baseline + 1)
        return ProcessingMeasures(
            barHeight: pt(bar.last - bar.first + 1),
            progressToHeaderInk: pt(header.inkTop - bar.last - 1),
            headerBaselineToHeadlineInk: pt(headlineTop - header.baseline),
            titleBaselineToSubtitleCap: pt(subtitleTop - title.baseline),
            titleBaselineToSubtitleBaseline: pt(subtitleBaseline - title.baseline)
        )
    }

    private func barRows() throws -> (first: Int, last: Int) {
        var first: Int?
        var last: Int?
        for y in 0..<height {
            if longestWhiteRun(y) > px(80) {
                if first == nil { first = y }
                last = y
            } else if first != nil {
                break
            }
        }
        guard let first, let last, last - first < px(8) else {
            throw InkError.missing("progress bar")
        }
        return (first, last)
    }

    func assertFigmaTrackAndHeaderInk() throws {
        let bar = try barRows()
        let y = (bar.first + bar.last) / 2
        let background = rgb(px(8), y)
        var lastWhite = -1
        for x in 0..<width where isWhiteInk(x, y) {
            lastWhite = x
        }
        let trackX = lastWhite + px(10)
        guard lastWhite > px(40), trackX < width - px(2) else {
            throw InkError.missing("progress track")
        }
        let track = rgb(trackX, y)
        let expected = blend(background, opacity: 0.25)
        let old = blend(background, opacity: 0.35)
        let tolerance = 13
        let separation = max(
            abs(expected.0 - old.0),
            abs(expected.1 - old.1),
            abs(expected.2 - old.2)
        )
        XCTAssertGreaterThan(
            separation,
            tolerance,
            "background \(background) does not separate 25% white from 35%"
        )
        XCTAssertTrue(
            close(track, expected, tolerance: tolerance),
            "track \(track) expected \(expected) bg \(background)"
        )
        XCTAssertFalse(
            close(track, old, tolerance: tolerance),
            "35% white \(old) must fail the same check; track \(track)"
        )

        let header = try inkBand(after: bar.last + 1, label: "header", matches: isHeaderInk)
        let darkest = darkestInk(from: header.inkTop, through: header.inkBottom)
        XCTAssertTrue(
            isPrimaryHeaderInk(darkest),
            "darkest header ink \(darkest) was not near #1A1A1A"
        )
        XCTAssertFalse(
            isPrimaryHeaderInk((r: 0x33, g: 0x1A, b: 0x00)),
            "#331A00 must fail the header ink predicate"
        )
    }

    private func isPrimaryHeaderInk(_ sample: (r: Int, g: Int, b: Int)) -> Bool {
        let (r, g, b) = sample
        return abs(r - g) <= 12 && abs(g - b) <= 12 && r < 0x30 && abs(r - 0x1A) <= 16
    }

    private func inkBand(
        after start: Int,
        label: String,
        matches: (Int, Int) -> Bool
    ) throws -> (inkTop: Int, baseline: Int, inkBottom: Int) {
        let top = try firstRow(after: start, where: matches, label: label)
        var bottoms: [Int] = []
        var inkBottom = top
        let limit = min(height, top + px(80))
        for x in 0..<width {
            var bottom = -1
            for y in top..<limit where matches(x, y) {
                bottom = y
            }
            if bottom >= 0 {
                bottoms.append(bottom)
                inkBottom = max(inkBottom, bottom)
            }
        }
        guard let baseline = mode(bottoms) else { throw InkError.missing("\(label) baseline") }
        return (top, baseline, inkBottom)
    }

    private func greyBaseline(after start: Int) throws -> Int {
        let top = try firstRow(after: start, where: isGreyInk, label: "subtitle")
        var bottoms: [Int] = []
        let limit = min(height, top + px(40))
        for x in px(40)..<max(px(40), width - px(40)) {
            var bottom = -1
            for y in top..<limit where isGreyInk(x, y) {
                bottom = y
            }
            if bottom >= 0 { bottoms.append(bottom) }
        }
        guard let baseline = mode(bottoms) else { throw InkError.missing("subtitle baseline") }
        return baseline
    }

    private func firstRow(after start: Int, where match: (Int, Int) -> Bool, label: String) throws -> Int {
        for y in max(0, start)..<height {
            for x in 0..<width where match(x, y) {
                return y
            }
        }
        throw InkError.missing(label)
    }

    private func longestWhiteRun(_ y: Int) -> Int {
        var run = 0
        var best = 0
        for x in 0..<width {
            if isWhiteInk(x, y) {
                run += 1
                best = max(best, run)
            } else {
                run = 0
            }
        }
        return best
    }

    /// Header glyph. Figma `text/headings` is #1A1A1A. Same manhattan budget as the old #331A00 window.
    private func isHeaderInk(_ x: Int, _ y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        return abs(Int(r) - 0x1A) + abs(Int(g) - 0x1A) + abs(Int(b) - 0x1A) < 80
    }

    /// Status-card title stays DS `Text.heading` `#331A00`.
    private func isBrownInk(_ x: Int, _ y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        return abs(Int(r) - 0x33) + abs(Int(g) - 0x1A) + abs(Int(b) - 0x00) < 80
    }

    private func darkestInk(from top: Int, through bottom: Int) -> (r: Int, g: Int, b: Int) {
        var best = (r: 255, g: 255, b: 255)
        var bestSum = Int.max
        let limit = min(height - 1, bottom)
        guard top <= limit else { return best }
        for y in top...limit {
            for x in 0..<width {
                let (r, g, b) = rgb(x, y)
                let sum = Int(r) + Int(g) + Int(b)
                if sum < bestSum {
                    bestSum = sum
                    best = (Int(r), Int(g), Int(b))
                }
            }
        }
        return best
    }

    private func blend(_ background: (UInt8, UInt8, UInt8), opacity: Double) -> (Int, Int, Int) {
        func mix(_ channel: UInt8) -> Int {
            Int((opacity * 255.0 + (1.0 - opacity) * Double(channel)).rounded())
        }
        return (mix(background.0), mix(background.1), mix(background.2))
    }

    private func close(
        _ actual: (UInt8, UInt8, UInt8),
        _ expected: (Int, Int, Int),
        tolerance: Int
    ) -> Bool {
        abs(Int(actual.0) - expected.0) <= tolerance &&
            abs(Int(actual.1) - expected.1) <= tolerance &&
            abs(Int(actual.2) - expected.2) <= tolerance
    }

    private func isWhiteInk(_ x: Int, _ y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        return r > 235 && g > 235 && b > 235
    }

    private func isGreyInk(_ x: Int, _ y: Int) -> Bool {
        let (r, g, b) = rgb(x, y)
        let spread = max(r, g, b) - min(r, g, b)
        let luma = (Int(r) + Int(g) + Int(b)) / 3
        return spread < 18 && luma > 70 && luma < 170
    }

    private func rgb(_ x: Int, _ y: Int) -> (UInt8, UInt8, UInt8) {
        let i = (y * width + x) * 4
        let a = Int(bytes[i + 3])
        guard a > 0 else { return (0, 0, 0) }
        return (
            UInt8(min(255, Int(bytes[i]) * 255 / a)),
            UInt8(min(255, Int(bytes[i + 1]) * 255 / a)),
            UInt8(min(255, Int(bytes[i + 2]) * 255 / a))
        )
    }

    private func mode(_ values: [Int]) -> Int? {
        Dictionary(grouping: values, by: { $0 }).max(by: { $0.value.count < $1.value.count })?.key
    }

    private func px(_ points: CGFloat) -> Int { Int((points * scale).rounded()) }

    private func pt(_ pixels: Int) -> CGFloat { CGFloat(pixels) / scale }
}

private enum InkError: Error, CustomStringConvertible {
    case unrendered
    case missing(String)

    var description: String {
        switch self {
        case .unrendered: return "unrendered"
        case .missing(let what): return "missing \(what)"
        }
    }
}
