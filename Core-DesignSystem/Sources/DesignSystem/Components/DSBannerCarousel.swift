import SwiftUI

/// Horizontal, "peeking" promo-banner carousel with a swipe page indicator.
///
/// Uses `containerRelativeFrame` + `.scrollTargetBehavior(.viewAligned)` + `.safeAreaPadding`
/// (iOS 17's "one page wide, neighbors peek at the edges" pattern) rather than
/// `TabView(.page)`, which hides neighboring pages entirely.
///
/// Each item currently renders as a flat color rectangle — no text/copy or artwork yet, see
/// `Item`. Tapping any banner shows the shared under-construction alert until real banner
/// destinations exist.
public struct DSBannerCarousel: View {
    /// Placeholder banner content: just a background color until real banner
    /// copy/artwork is wired up.
    public struct Item: Identifiable, Hashable {
        public let id: Int
        public let backgroundColor: Color

        public init(id: Int, backgroundColor: Color) {
            self.id = id
            self.backgroundColor = backgroundColor
        }
    }

    let items: [Item]
    /// Seconds the active banner stays on screen before auto-advancing to the next one
    /// (looping back to the first after the last). `nil` disables auto-advance — banners
    /// only change via manual swipe, and the active page indicator renders fully filled
    /// rather than animating.
    let autoAdvanceInterval: Double?

    @State private var scrolledItemID: Item.ID?
    @State private var showsUnderConstructionAlert = false
    /// Active indicator's white→orange fill fraction (0...1). Held at `1` when
    /// `autoAdvanceInterval` is `nil`; otherwise driven tick-by-tick from `0` to `1` over
    /// `autoAdvanceInterval` seconds, like a story-style countdown bar.
    @State private var progress: Double
    /// Set for as long as the user's finger is down on a banner. `runAutoAdvanceCountdown`
    /// simply stops accumulating elapsed time while this is `true`, freezing `progress` in
    /// place (Instagram Stories-style pause) instead of resetting or cancelling the countdown.
    @State private var isPressed = false

    private static let bannerHeight: CGFloat = 80
    private static let itemSpacing: CGFloat = DSConstant.small.value
    private static let cornerRadius: CGFloat = DSConstant.cardCornerRadius.value
    private static let indicatorHeight: CGFloat = 3
    private static let indicatorActiveWidth: CGFloat = 24
    private static let indicatorInactiveWidth: CGFloat = 8
    /// Countdown update rate. Frequent-but-discrete steps (rather than one long `withAnimation`
    /// from 0→1) are what make pausing/resuming mid-flight possible — each step just checks
    /// `isPressed` before advancing `progress` further.
    private static let tickInterval: Double = 1.0 / 30.0

    public init(items: [Item], autoAdvanceInterval: Double? = nil) {
        self.items = items
        self.autoAdvanceInterval = autoAdvanceInterval
        _scrolledItemID = State(initialValue: items.first?.id)
        _progress = State(initialValue: autoAdvanceInterval == nil ? 1 : 0)
    }

    public var body: some View {
        VStack(spacing: DSConstant.small.value) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Self.itemSpacing) {
                    ForEach(items) { item in
                        banner(item)
                            .containerRelativeFrame(.horizontal, count: 1, span: 1, spacing: Self.itemSpacing)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrolledItemID)
            .safeAreaPadding(.horizontal, DSConstant.mediumLarge.value)
            .frame(height: Self.bannerHeight)

            if items.count > 1 {
                pageIndicator
            }
        }
        .featureUnderConstructionAlert(isPresented: $showsUnderConstructionAlert)
        .task(id: scrolledItemID) {
            await runAutoAdvanceCountdown()
        }
    }

    /// Plain `.onTapGesture` (not a `Button`) alongside `.onLongPressGesture` purely to
    /// observe press-down/press-up for pausing the countdown — a `Button`'s own gesture
    /// would fight a second gesture recognizer on the same view.
    ///
    /// This intentionally isn't a zero-distance `DragGesture`/`LongPressGesture` wrapped in
    /// `.simultaneousGesture`: that recognizes on the very first touch with zero movement,
    /// which "wins" the gesture arena immediately and blocks the enclosing `ScrollView` from
    /// ever recognizing a swipe. A small `minimumDuration` + `maximumDistance` lets a real
    /// swipe's movement fail the long-press before it fires, releasing the touch back to the
    /// scroll view, while a stationary press still pauses almost immediately.
    private func banner(_ item: Item) -> some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .fill(item.backgroundColor)
            .contentShape(Rectangle())
            .onTapGesture {
                showsUnderConstructionAlert = true
            }
            .onLongPressGesture(
                minimumDuration: 0.15,
                maximumDistance: 10,
                pressing: { isPressed = $0 },
                perform: {}
            )
            .accessibilityAddTraits(.isButton)
    }

    private var selectedIndex: Int {
        items.firstIndex { $0.id == scrolledItemID } ?? 0
    }

    private var pageIndicator: some View {
        HStack(spacing: DSConstant.xSmall.value) {
            ForEach(items.indices, id: \.self) { index in
                indicator(isActive: index == selectedIndex)
            }
        }
        .animation(.default, value: selectedIndex)
        .accessibilityHidden(true)
    }

    /// Inactive dots are flat white. The active one layers an orange fill (width driven by
    /// `progress`) over a white track — a fully filled pill when there's no auto-advance,
    /// or a left-to-right countdown when there is.
    private func indicator(isActive: Bool) -> some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white)
            if isActive {
                Capsule()
                    .fill(DSColor.Background.Button.primary)
                    .frame(width: Self.indicatorActiveWidth * progress)
                    .animation(.linear(duration: Self.tickInterval), value: progress)
            }
        }
        .frame(
            width: isActive ? Self.indicatorActiveWidth : Self.indicatorInactiveWidth,
            height: Self.indicatorHeight
        )
    }

    /// Re-runs from scratch whenever `scrolledItemID` changes — via SwiftUI's `.task(id:)`
    /// auto-cancellation — whether that change came from this same countdown advancing the
    /// page, or from the user manually swiping. Ticks in small steps (rather than one long
    /// animation) purely so `isPressed` can be checked before each step — freezing `progress`
    /// mid-flight while pressed, then continuing on from the same point on release.
    private func runAutoAdvanceCountdown() async {
        guard let autoAdvanceInterval, items.count > 1 else {
            progress = 1
            return
        }
        progress = 0
        var elapsed: Double = 0
        while elapsed < autoAdvanceInterval {
            try? await Task.sleep(for: .seconds(Self.tickInterval))
            guard !Task.isCancelled else { return }
            if !isPressed {
                elapsed += Self.tickInterval
                progress = min(elapsed / autoAdvanceInterval, 1)
            }
        }
        guard !Task.isCancelled else { return }
        advanceToNextItem()
    }

    private func advanceToNextItem() {
        guard let currentIndex = items.firstIndex(where: { $0.id == scrolledItemID }) else { return }
        let nextIndex = (currentIndex + 1) % items.count
        withAnimation {
            scrolledItemID = items[nextIndex].id
        }
    }
}

#Preview("DSBannerCarousel") {
    DSBannerCarousel(items: [
        .init(id: 0, backgroundColor: DSColor.Background.brown),
        .init(id: 1, backgroundColor: DSColor.Background.pink),
        .init(id: 2, backgroundColor: DSColor.Background.green)
    ])
    .padding(.vertical)
    .background(Color(white: 0.95))
}

#Preview("DSBannerCarousel — auto-advancing") {
    DSBannerCarousel(
        items: [
            .init(id: 0, backgroundColor: DSColor.Background.brown),
            .init(id: 1, backgroundColor: DSColor.Background.pink),
            .init(id: 2, backgroundColor: DSColor.Background.green)
        ],
        autoAdvanceInterval: 3
    )
    .padding(.vertical)
    .background(Color(white: 0.95))
}
