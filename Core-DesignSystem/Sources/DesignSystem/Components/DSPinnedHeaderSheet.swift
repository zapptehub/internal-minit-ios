import SwiftUI

/// A scrollable screen layout where `header` stays visually pinned in place while a white,
/// rounded-corner `sheet` scrolls up from underneath it and eventually covers it — the same
/// "profile header + sheet" pattern used by many list-detail screens (e.g. a hero image with
/// a card of content sliding up over it).
///
/// There is no built-in SwiftUI API for this exact effect (a header that stays fixed *and*
/// gets covered by scrolling content, as opposed to `.safeAreaInset`'s always-on-top pinning
/// or a plain sticky section header). Instead this reproduces it with a small scroll-tracking
/// trick:
///
/// 1. `header` is laid out first inside the scrolling content, on top of a `Color.clear`
///    spacer reserving its own height (`headerHeight`).
/// 2. As the user scrolls, `header` receives a counter-offset that exactly cancels out its own
///    scroll motion — see `pinnedHeader` below for the offset math — so it appears fixed.
/// 3. `sheet` is declared *after* `header` in the same `VStack`, so it draws on top and visually
///    slides up to cover the pinned header as scrolling continues.
public struct DSPinnedHeaderSheet<Header: View, Sheet: View>: View {
    private let header: () -> Header
    private let sheet: () -> Sheet

    /// The header's ideal height at the current width. Updated whenever the header
    /// grows (Dynamic Type, a name loading in) so the sheet starts below it instead
    /// of covering wrapped lines.
    @State private var headerHeight: CGFloat = 0
    /// Bottom safe area the scroll view draws under (tab bar). Added to the sheet
    /// so the last content can scroll to sit above that bar.
    @State private var bottomScrollInset: CGFloat = 0
    /// Captured once (`onAppear`): the scroll view's own fixed position in global coordinates.
    /// Doesn't change as the user scrolls (only the content inside it moves), but is needed to
    /// correctly zero out the header's offset at rest regardless of what sits above this view
    /// (safe area, a banner, etc.) without hardcoding that distance.
    @State private var scrollViewMinY: CGFloat = 0
    /// Tracked continuously (`onChange`) as `sheet` scrolls — its live top position in global
    /// coordinates, used to compute how far the content has scrolled.
    @State private var sheetOffsetY: CGFloat = 0

    public init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder sheet: @escaping () -> Sheet
    ) {
        self.header = header
        self.sheet = sheet
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: headerHeight)
                        .overlay(pinnedHeader(viewportHeight: geometry.size.height), alignment: .top)

                    sheetContent(geometry: geometry)
                }
            }
            .background(
                // Captures where the scroll view starts on screen in global coordinates —
                // used below in the pinned header's counter-offset.
                GeometryReader { scrollGeo in
                    Color.clear.onAppear {
                        scrollViewMinY = scrollGeo.frame(in: .global).minY
                    }
                }
            )
        }
        .ignoresSafeArea(edges: .bottom)
        // Ignoring the bottom edge lets the sheet fill run under the tab bar and
        // clears the geometry reader's own bottom inset (it reports 0). The safe
        // area on this modifier is the inset the parent still applies, including
        // a tab bar — the same value as the largest ancestor inset. Pad the scroll
        // content by it so the last row can rest above that bar. `onGeometryChange`
        // delivers the value after layout.
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.safeAreaInsets.bottom
        } action: { inset in
            if abs(bottomScrollInset - inset) > 0.5 {
                bottomScrollInset = inset
            }
        }
    }

    private func pinnedHeader(viewportHeight: CGFloat) -> some View {
        // A tight height proposal (the spacer starts at 0) would compress a wrapping
        // greeting to one truncated line and then lock that height in. Measure and
        // place the header at its ideal height for the proposed width instead.
        IdealHeightLayout {
            header()
        }
        .background(
            GeometryReader { headerGeo in
                Color.clear.preference(key: PinnedHeaderHeightKey.self, value: headerGeo.size.height)
            }
        )
        .onPreferenceChange(PinnedHeaderHeightKey.self) { newHeight in
            if newHeight > 0, abs(headerHeight - newHeight) > 0.5 {
                headerHeight = newHeight
            }
        }
        // At rest, `sheetOffsetY == scrollViewMinY + headerHeight`, so the offset is
        // `0`. Once the sheet scrolls up, this pushes the header back down so it stays
        // visually fixed. When the header is taller than the area above the tab bar,
        // the first part of the scroll moves the header with the content until its
        // bottom clears the bar; only then does it pin.
        .offset(y: pinOffset(viewportHeight: viewportHeight))
    }

    private func pinOffset(viewportHeight: CGFloat) -> CGFloat {
        let scrolled = headerHeight + scrollViewMinY - sheetOffsetY
        let visibleHeight = max(0, viewportHeight - bottomScrollInset)
        let overflow = max(0, headerHeight - visibleHeight)
        return max(0, scrolled - overflow)
    }

    private func sheetContent(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            handle
            sheet()
        }
        .padding(.bottom, bottomScrollInset)
        // Forces the sheet to be at least screen-tall so there's always something to
        // scroll — otherwise the pin/reveal effect can't be seen with little or no content.
        .frame(
            maxWidth: .infinity,
            minHeight: geometry.size.height - geometry.safeAreaInsets.top,
            alignment: .top
        )
        .background(DSColor.Background.Layer.level0)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
        .dsShadow(DSShadow.pinnedSheet)
        .overlay(
            // Tracks the sheet's live vertical position in global coordinates as it
            // scrolls — the pinned header uses this to compute its counter-offset.
            GeometryReader { sheetGeo in
                Color.clear.onChange(of: sheetGeo.frame(in: .global).minY) { _, newValue in
                    sheetOffsetY = newValue
                }
            }
        )
    }

    /// Decorative drag-handle grabber at the top of the sheet, matching Figma. Purely
    /// visual — the sheet doesn't support drag-to-dismiss, this just signals "sheet" the
    /// same way system sheets do. `sheet()`'s own top padding (if any) provides the gap
    /// below the handle, so only top padding lives here.
    private var handle: some View {
        Capsule()
            // iOS's own grabber color (`UIColor.label` at 30% opacity) — matches Figma's
            // "#3C3C434D" spec exactly, no dedicated DSColor token for this one-off.
            .fill(Color(red: 0x3C / 255, green: 0x3C / 255, blue: 0x43 / 255).opacity(0.3))
            .frame(
                width: DSComponentMetric.PinnedSheet.handleWidth,
                height: DSComponentMetric.PinnedSheet.handleHeight
            )
            .padding(.top, DSComponentMetric.PinnedSheet.handleTopPadding)
            .accessibilityHidden(true)
    }
}

/// Sizes and places `content` at its ideal height for the proposed width.
///
/// A proposed height of 0 (the spacer before the first measurement) would otherwise
/// compress wrapping text to a single truncated line.
private struct IdealHeightLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        let ideal = child.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: proposal.width ?? ideal.width, height: ideal.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        child.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: ProposedViewSize(width: bounds.width, height: nil)
        )
    }
}

private struct PinnedHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview("DSPinnedHeaderSheet") {
    DSPinnedHeaderSheet(
        header: {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text("Pinned header")
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.inverse)
                Text("Scroll the sheet below — this stays in place, then gets covered.")
                    .typography(.uiRegular)
                    .foregroundColor(DSColor.Text.inverse.opacity(0.8))
            }
            .padding(DSConstant.mediumLarge.value)
            .frame(maxWidth: .infinity, alignment: .leading)
        },
        sheet: {
            Color.clear
        }
    )
    .background(DSColor.Background.brown.ignoresSafeArea())
}

#Preview("DSPinnedHeaderSheet — with sheet content") {
    DSPinnedHeaderSheet(
        header: {
            VStack(alignment: .leading, spacing: DSConstant.small.value) {
                Text("Pinned header")
                    .typography(.headingLargeSemibold)
                    .foregroundColor(DSColor.Text.inverse)
                Text("The sheet below has some content this time.")
                    .typography(.uiRegular)
                    .foregroundColor(DSColor.Text.inverse.opacity(0.8))
            }
            .padding(DSConstant.mediumLarge.value)
            .frame(maxWidth: .infinity, alignment: .leading)
        },
        sheet: {
            VStack(alignment: .leading, spacing: DSConstant.medium.value) {
                ForEach(0..<20) { index in
                    Text("Sheet row \(index)")
                        .typography(.uiRegular)
                        .foregroundColor(DSColor.Text.primary)
                }
            }
            .padding(DSConstant.mediumLarge.value)
        }
    )
    .background(DSColor.Background.brown.ignoresSafeArea())
}
