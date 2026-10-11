import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// Rendered status-card box at the Figma content width (354) and default
/// Dynamic Type. Heights follow the cap-trimmed Sharp Grotesk title, so the
/// previous 24pt padding and `uiLargeBold` title do not land on these numbers.
@MainActor
final class StatusCardSpacingTests: XCTestCase {
    func testLoadingAndSuccessHeightsAtFigmaWidth() {
        let loading = Self.measure(
            DSStatusCard(state: .loading(
                title: "Creating loyalty card...",
                subtitle: "This may take a second"
            ))
            .frame(width: 354)
        )
        let success = Self.measure(
            DSStatusCard(state: .success(title: "Loyalty card was added successfully"))
                .frame(width: 354)
        )
        let loadingLines = Self.lineCount(of: "Creating loyalty card...", width: 290)
        let successLines = Self.lineCount(of: "Loyalty card was added successfully", width: 290)

        XCTAssertEqual(loading.width, 354, accuracy: 1)
        XCTAssertEqual(success.width, 354, accuracy: 1)
        // Was 176.34 with paragraphRegular. Body/Medium/small's line box measures
        // 20.33 (Figma 20; SwiftUI rounds the 14pt system face).
        // 32 + 48 + 24 + 14.34 + 8 + 20.33 + 32 = 178.67. Figma loading is 177.
        XCTAssertEqual(loading.height, 178.67, accuracy: 0.75, "loading \(loading.height)")
        // 32 + 48 + 24 + (14.34 + 23) + 32. Line spacing 0 lands on 170.34.
        XCTAssertEqual(success.height, 173.34, accuracy: 0.75, "success \(success.height)")
        XCTAssertEqual(loadingLines, 1, "loading title wrapped")
        XCTAssertEqual(successLines, 2, "success title line count \(successLines)")
    }

    /// Two-line trim must keep the second line. The old single-line box was
    /// only the cap height, which would collapse this title.
    func testWrappedTitleBoxKeepsTheSecondLine() {
        let oneLine = Self.measure(
            SharpGroteskCapTrim(followingGap: StatusCardMetrics.titleToSubtitleSpacing) {
                Text("Creating loyalty card...")
                    .typography(StatusCardMetrics.titleStyle)
                    .lineSpacing(StatusCardMetrics.titleLineSpacing)
                    .frame(width: 290)
            }
        )
        let twoLines = Self.measure(
            SharpGroteskCapTrim(followingGap: StatusCardMetrics.contentPadding) {
                Text("Loyalty card was added successfully")
                    .typography(StatusCardMetrics.titleStyle)
                    .lineSpacing(StatusCardMetrics.titleLineSpacing)
                    .multilineTextAlignment(.center)
                    .frame(width: 290)
            }
        )
        XCTAssertLessThan(oneLine.height, 22, "one line should stay near the cap height, was \(oneLine.height)")
        XCTAssertEqual(oneLine.height, 14.34, accuracy: 0.5, "one-line box \(oneLine.height)")
        XCTAssertGreaterThan(
            twoLines.height,
            oneLine.height + 12,
            "wrapped title collapsed to one cap box (\(twoLines.height) vs \(oneLine.height))"
        )
        // Cap 14.34 + baseline span 23. Line spacing 0 lands on 34.34.
        XCTAssertEqual(twoLines.height, 37.34, accuracy: 0.75, "two-line box \(twoLines.height)")
    }

    private static func lineCount(of text: String, width: CGFloat) -> Int {
        let wrapped = measure(
            Text(text)
                .typography(StatusCardMetrics.titleStyle)
                .multilineTextAlignment(.center)
                .frame(width: width)
        ).height
        let single = measure(
            Text(text)
                .typography(StatusCardMetrics.titleStyle)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: true)
        ).height
        guard single > 1 else { return 1 }
        return Int((wrapped / single).rounded())
    }

    private static func measure<V: View>(_ view: V) -> CGSize {
        let store = SizeStore()
        let root = SizeProbe(store: store) {
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

private final class SizeStore {
    var size: CGSize = .zero
}

private struct SizeProbe<Content: View>: View {
    let store: SizeStore
    @ViewBuilder var content: () -> Content

    var body: some View {
        SizeProbeLayout(store: store) { content() }
    }
}

private struct SizeProbeLayout: Layout {
    let store: SizeStore

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
