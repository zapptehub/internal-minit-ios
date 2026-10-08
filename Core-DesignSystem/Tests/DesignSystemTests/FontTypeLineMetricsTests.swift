import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Figma line boxes for Body/Medium/small and Heading/H1. `.lineSpacing` alone
/// leaves a single line at the font's own height; the half-leading padding is
/// what makes that box 20 or 44.
@MainActor
final class FontTypeLineMetricsTests: XCTestCase {
    func testBodyMediumSmallAndHeadingLineBoxesMatchFigma() {
        let body = Self.measure(
            Text("Every bite")
                .typography(.bodyMediumSmall)
                .fixedSize()
        )
        let heading = Self.measure(
            Text("What")
                .typography(.headingLargeSemibold)
                .fixedSize()
        )
        let wrapped = Self.measure(
            Text("Choose your\napp language")
                .typography(.headingLargeSemibold)
                .fixedSize()
        )
        print(
            "ONB_TYPO ios lineBox body=\(body.height) heading=\(heading.height) " +
            "wrapped=\(wrapped.height)"
        )
        XCTAssertEqual(body.height, 20, accuracy: 0.75, "body \(body.height)")
        XCTAssertEqual(heading.height, 44, accuracy: 0.75, "heading \(heading.height)")
        XCTAssertEqual(wrapped.height, 88, accuracy: 0.75, "two-line heading \(wrapped.height)")
    }

    /// Figma "Heading/H2" (Home greeting, node 6064:4622): 30pt Sharp Grotesk with a
    /// "normal" line height whose box is 38pt; tracking 0.
    func testHeadingH2LineBoxMatchesFigmaGreeting() {
        let lineBox = FontType.headingH2.figmaLineBox
        XCTAssertEqual(lineBox?.lineHeight, 38)
        XCTAssertEqual(lineBox?.naturalLineHeight, 30)
        XCTAssertEqual(lineBox?.lineSpacing, 8)
        XCTAssertEqual(lineBox?.halfLeading, 4)
        XCTAssertEqual(FontType.headingH2.tracking, 0)

        let greeting = Self.measure(
            Text("Dobré ráno Iveta")
                .typography(.headingH2)
                .fixedSize()
        )
        XCTAssertEqual(greeting.height, 38, accuracy: 0.75, "headingH2 \(greeting.height)")
    }

    func testParagraphRegularTypographyDoesNotAddLineBoxPadding() {
        let styled = Self.measure(
            Text("Hello")
                .typography(.paragraphRegular)
                .fixedSize()
        )
        let plain = Self.measure(
            Text("Hello")
                .font(FontType.paragraphRegular.font)
                .tracking(FontType.paragraphRegular.tracking)
                .fixedSize()
        )
        XCTAssertEqual(styled.height, plain.height, accuracy: 0.5, "styled \(styled.height) plain \(plain.height)")
        XCTAssertNil(FontType.paragraphRegular.figmaLineBox)
    }

    private static func measure<V: View>(_ view: V) -> CGSize {
        let store = LineMetricSizeStore()
        let root = LineMetricSizeProbe(store: store) {
            view.environment(\.dynamicTypeSize, .large)
        }
        let host = UIHostingController(rootView: root)
        host.safeAreaRegions = []
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        return store.size
    }
}

private final class LineMetricSizeStore {
    var size: CGSize = .zero
}

private struct LineMetricSizeProbe<Content: View>: View {
    let store: LineMetricSizeStore
    @ViewBuilder var content: () -> Content

    var body: some View {
        LineMetricSizeLayout(store: store) { content() }
    }
}

private struct LineMetricSizeLayout: Layout {
    let store: LineMetricSizeStore

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews[0].sizeThatFits(proposal)
        store.size = size
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = subviews[0].sizeThatFits(proposal)
        store.size = size
        subviews[0].place(at: bounds.origin, proposal: proposal)
    }
}
