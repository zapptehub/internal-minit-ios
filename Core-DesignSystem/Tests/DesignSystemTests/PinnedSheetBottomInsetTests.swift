import SwiftUI
import UIKit
import XCTest
@testable import DesignSystem

/// The sheet ignores the bottom safe area so its fill runs under the tab bar, then
/// pads the scroll content by that inset. The padding has to match the largest
/// ancestor bottom inset — the value that keeps Challenges above the tab bar.
@MainActor
final class PinnedSheetBottomInsetTests: XCTestCase {
    func testSheetPaddingMatchesTheTabBarInset() {
        assertContentClearsAncestorBottomInset(dynamicTypeSize: .large, inTab: true)
    }

    func testSheetPaddingMatchesTheTabBarInsetAtLargestDynamicType() {
        assertContentClearsAncestorBottomInset(dynamicTypeSize: .accessibility5, inTab: true)
    }

    func testSheetPaddingMatchesAnExtraBottomSafeArea() {
        assertContentClearsAncestorBottomInset(dynamicTypeSize: .large, inTab: false, extraBottom: 83)
    }

    private func assertContentClearsAncestorBottomInset(
        dynamicTypeSize: DynamicTypeSize,
        inTab: Bool,
        extraBottom: CGFloat = 0
    ) {
        let box = AnchorBox()
        let sheet = DSPinnedHeaderSheet(
            header: {
                Text(String(repeating: "Good morning ", count: 8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            sheet: {
                Color.clear
                    .frame(height: 4000)
                    .background {
                        FrameAnchor { box.anchor = $0 }
                    }
            }
        )
        .environment(\.dynamicTypeSize, dynamicTypeSize)
        .background(Color.brown.ignoresSafeArea())

        let root: AnyView
        if inTab {
            root = AnyView(
                TabView {
                    sheet.tabItem { Label("Home", systemImage: "house") }
                }
                .dsPopupHost()
            )
        } else {
            root = AnyView(sheet)
        }

        let host = UIHostingController(rootView: root)
        if extraBottom > 0 {
            host.additionalSafeAreaInsets.bottom = extraBottom
        }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        defer { window.isHidden = true }

        let matched = pump(timeout: 2) {
            guard let measurement = measuredGap(box) else { return false }
            return abs(measurement.gap - measurement.ancestorMax) <= 0.5 && measurement.ancestorMax > 0.5
        }
        guard let measurement = measuredGap(box), measurement.anchorHeight > 1000 else {
            XCTFail("sheet did not lay out. anchor=\(String(describing: box.anchor)) measurement=\(String(describing: measuredGap(box)))")
            return
        }
        if !matched {
            XCTFail("bottom gap never matched the ancestor inset. \(measurement.description)")
        }

        if inTab {
            XCTAssertGreaterThan(
                measurement.ancestorMax,
                40,
                "expected a tab bar inset, got \(measurement.description)"
            )
        }
        if extraBottom > 0 {
            XCTAssertGreaterThanOrEqual(
                measurement.ancestorMax,
                extraBottom,
                measurement.description
            )
        }
        XCTAssertEqual(
            measurement.gap,
            measurement.ancestorMax,
            accuracy: 0.5,
            measurement.description
        )
        XCTAssertEqual(
            measurement.scrollMaxY,
            measurement.windowMaxY,
            accuracy: 1,
            "sheet should still fill under the bar. \(measurement.description)"
        )
        XCTAssertLessThan(
            measurement.adjustedContentInsetBottom,
            1,
            "scroll view should not add the safe area again. \(measurement.description)"
        )
    }

    private func measuredGap(_ box: AnchorBox) -> GapMeasurement? {
        guard let anchor = box.anchor, anchor.window != nil, anchor.bounds.height > 1000,
              let scroll = enclosingScrollView(from: anchor) else {
            return nil
        }
        // `convert(_:to:)` is already in the scroll view's content coordinates.
        // Adding `contentOffset` again counts the top safe-area inset twice.
        let frame = anchor.convert(anchor.bounds, to: scroll)
        let gap = scroll.contentSize.height - frame.maxY
        let ancestorMax = maxBottomInset(from: anchor)
        let scrollFrame = scroll.convert(scroll.bounds, to: anchor.window)
        return GapMeasurement(
            gap: gap,
            ancestorMax: ancestorMax,
            scrollMaxY: scrollFrame.maxY,
            windowMaxY: anchor.window?.bounds.maxY ?? -1,
            adjustedContentInsetBottom: scroll.adjustedContentInset.bottom,
            contentSizeHeight: scroll.contentSize.height,
            anchorHeight: anchor.bounds.height
        )
    }

    private func maxBottomInset(from view: UIView) -> CGFloat {
        var bottom = view.safeAreaInsets.bottom
        var ancestor = view.superview
        while let next = ancestor {
            bottom = max(bottom, next.safeAreaInsets.bottom)
            ancestor = next.superview
        }
        return bottom
    }

    private func enclosingScrollView(from view: UIView) -> UIScrollView? {
        var current: UIView? = view
        while let view = current {
            if let scroll = view as? UIScrollView { return scroll }
            current = view.superview
        }
        return nil
    }

    private func pump(timeout: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            if condition() { return true }
        }
        return condition()
    }
}

private struct GapMeasurement: CustomStringConvertible {
    var gap: CGFloat
    var ancestorMax: CGFloat
    var scrollMaxY: CGFloat
    var windowMaxY: CGFloat
    var adjustedContentInsetBottom: CGFloat
    var contentSizeHeight: CGFloat
    var anchorHeight: CGFloat

    var description: String {
        "gap=\(gap) ancestorMax=\(ancestorMax) scrollMaxY=\(scrollMaxY) windowMaxY=\(windowMaxY) adjustedBottom=\(adjustedContentInsetBottom) contentHeight=\(contentSizeHeight) anchorHeight=\(anchorHeight)"
    }
}

private final class AnchorBox {
    weak var anchor: UIView?
}

private struct FrameAnchor: UIViewRepresentable {
    var onResolve: (UIView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        onResolve(uiView)
    }
}
