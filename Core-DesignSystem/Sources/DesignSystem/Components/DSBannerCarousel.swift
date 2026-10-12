import SwiftUI

/// Horizontal, "peeking" promo-banner carousel with a swipe page indicator.
///
/// Uses `containerRelativeFrame` + `.scrollTargetBehavior(.viewAligned)` + `.safeAreaPadding`
/// (iOS 17's "one page wide, neighbors peek at the edges" pattern) rather than
/// `TabView(.page)`, which hides neighboring pages entirely.
///
/// Each item fills with `backgroundColor`; optional `image` / `badgeText` / `title` layer
/// content on top when provided. Tapping any banner shows the shared under-construction
/// alert until real banner destinations exist. Pass `onBannerTap` when the caller
/// presents that alert itself; `nil` keeps the alert here.
public struct DSBannerCarousel: View {
    /// Banner slot: required fill color, plus optional artwork and copy.
    ///
    /// `title` is a pre-built `Text` (not a plain `String`) so callers can concatenate
    /// differently-colored runs themselves — same idiom as `HomeScreen.greeting` — keeping
    /// the carousel agnostic to per-word coloring/localization. Not `Hashable` because
    /// `Text` isn't, and nothing here requires it (`ForEach` / `.scrollPosition` only need
    /// `Identifiable`).
    public struct Item: Identifiable {
        public let id: Int
        public let backgroundColor: Color
        public let image: DSImage?
        public let badgeText: String?
        public let title: Text?

        public init(
            id: Int,
            backgroundColor: Color,
            image: DSImage? = nil,
            badgeText: String? = nil,
            title: Text? = nil
        ) {
            self.id = id
            self.backgroundColor = backgroundColor
            self.image = image
            self.badgeText = badgeText
            self.title = title
        }
    }

    let items: [Item]
    /// When set, a banner tap calls this instead of the built-in under-construction alert.
    let onBannerTap: (() -> Void)?
    /// Replaces the generated badge-and-title label on every page. Notifications
    /// passes its own daily-offer name; Home leaves this nil.
    let accessibilityLabelOverride: String?
    /// Seconds the active banner stays on screen before auto-advancing to the next one
    /// (looping back to the first after the last). `nil` disables auto-advance — banners
    /// only change via manual swipe, and the active page indicator renders fully filled
    /// rather than animating.
    let autoAdvanceInterval: Double?

    @State private var scrolledItemID: Item.ID?
    @State private var showsUnderConstructionAlert = false
    /// Active indicator's white→orange fill fraction (0...1). Held at `1` when
    /// `autoAdvanceInterval` is `nil` or Reduce Motion is on (the countdown's end
    /// state); otherwise driven tick-by-tick from `0` to `1` over
    /// `autoAdvanceInterval` seconds, like a story-style countdown bar.
    @State private var progress: Double
    /// Set for as long as the user's finger is down on a banner. `runAutoAdvanceCountdown`
    /// simply stops accumulating elapsed time while this is `true`, freezing `progress` in
    /// place (Instagram Stories-style pause) instead of resetting or cancelling the countdown.
    @State private var isPressed = false
    /// Ideal height of the tallest page's copy. The row stays 80 until the
    /// wrapped title needs more, matching Android `heightIn(min = 80.dp)`.
    @State private var bannerContentHeight: CGFloat = 0
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let bannerMinHeight: CGFloat = 80
    static let itemSpacing: CGFloat = DSConstant.small.value
    /// Figma Home "Offers" (6065:4746): the active banner sits 20 from each screen edge
    /// (x 20, width 362 on a 402 screen) with 8 (`itemSpacing`) to its neighbours, so they
    /// peek 12 in. Was 16 (`DSConstant.mediumLarge`). A single banner (Notifications) has
    /// no inset and takes its container's own 20 padding.
    static let multiPageHorizontalInset: CGFloat = DSPrimitiveScale.step500.value
    private static let cornerRadius: CGFloat = DSConstant.cardCornerRadius.value
    private static let indicatorHeight: CGFloat = 3
    private static let indicatorActiveWidth: CGFloat = 24
    private static let indicatorInactiveWidth: CGFloat = 8
    /// Decorative artwork sits top-trailing, sized to roughly fill the banner's height
    /// while still tucking behind the title/button content in front of it.
    private static let illustrationSize = CGSize(width: bannerMinHeight, height: bannerMinHeight)
    private static let arrowButtonDiameter: CGFloat = 32
    private static let arrowIconSize: CGFloat = 16
    /// Warm tan mock color for the "Daily Offer" badge, uniform across every banner fill
    /// (light or dark) — matches the mock's badge tone rather than deriving from
    /// `backgroundColor`. No dedicated Figma token to copy this round.
    private static let badgeTextColor = Color(red: 0.878, green: 0.725, blue: 0.569)
    /// Countdown update rate. Frequent-but-discrete steps (rather than one long `withAnimation`
    /// from 0→1) are what make pausing/resuming mid-flight possible — each step just checks
    /// `isPressed` before advancing `progress` further.
    private static let tickInterval: Double = 1.0 / 30.0

    /// Figma effect style "Small" on every Daily Offer banner (Home 6065:4747, Notifications
    /// 6123:1697): the shared `DSShadow.small` token, also on the Challenge cards.
    static let shadow = DSShadow.small

    public init(
        items: [Item],
        autoAdvanceInterval: Double? = nil,
        initialIndex: Int = 0,
        onBannerTap: (() -> Void)? = nil,
        accessibilityLabel: String? = nil
    ) {
        self.items = items
        self.onBannerTap = onBannerTap
        self.accessibilityLabelOverride = accessibilityLabel
        self.autoAdvanceInterval = autoAdvanceInterval
        let startIndex = items.indices.contains(initialIndex) ? initialIndex : 0
        _scrolledItemID = State(initialValue: items.isEmpty ? nil : items[startIndex].id)
        _progress = State(initialValue: autoAdvanceInterval == nil ? 1 : 0)
    }

    public var body: some View {
        bannerStack
            // The scroll container does not publish each page, so the badge and
            // title were separate buttons and off-screen pages stayed visible.
            // One element stands in for the page that is current.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(currentBannerAccessibilityText)
            .accessibilityValue(currentBannerPositionDescription)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, activateBanner)
            // VoiceOver swipe up/down. Stops on the first and last banners.
            // The scroll view and the page indicator both follow `scrolledItemID`;
            // `DSMotion` snaps that move when Reduce Motion is on.
            .accessibilityAdjustableAction(adjustCurrentBanner)
            .task(id: scrolledItemID) {
                await runAutoAdvanceCountdown()
            }
    }

    @ViewBuilder
    private var bannerStack: some View {
        if onBannerTap == nil {
            bannerColumn.featureUnderConstructionAlert(isPresented: $showsUnderConstructionAlert)
        } else {
            bannerColumn
        }
    }

    private var bannerColumn: some View {
        VStack(spacing: DSConstant.small.value) {
            scrollView
                .frame(height: max(Self.bannerMinHeight, bannerContentHeight))

            if items.count > 1 {
                pageIndicator
            }
        }
        .onPreferenceChange(BannerContentHeightKey.self) { newHeight in
            if abs(bannerContentHeight - newHeight) > 0.5 {
                bannerContentHeight = newHeight
            }
        }
    }

    /// Only reserves horizontal safe-area padding for the "peeking neighbor" look when
    /// there's more than one banner to peek at. A single banner (e.g. Notifications'
    /// Daily Offer) fills whatever width its container gives it instead — relying on
    /// the container's own padding rather than stacking a second layer of inset on
    /// top of it.
    @ViewBuilder
    private var scrollView: some View {
        let content = ScrollView(.horizontal, showsIndicators: false) {
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
        // The banner shadows reach 28 to the sides and 44 below the 80pt row; without
        // this the scroll view would cut them off at its frame. Layout is unchanged.
        .scrollClipDisabled()

        if items.count > 1 {
            content.safeAreaPadding(.horizontal, Self.multiPageHorizontalInset)
        } else {
            content
        }
    }

    /// Opaque banner-shaped layers behind the banner that cast Figma's two shadows. They
    /// are filled with the banner's own color and hidden by it, so only the shadows show.
    static func shadowCasters(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius - shadow.farCasterInset, style: .continuous)
                .fill(color)
                .padding(shadow.farCasterInset)
                .dsShadow(shadow.far)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(color)
                .dsShadow(shadow.near)
        }
        .accessibilityHidden(true)
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
        ZStack(alignment: .topTrailing) {
            if let image = item.image {
                DSImageView(image: image, size: Self.illustrationSize, contentMode: .fill)
                    .allowsHitTesting(false)
                    .padding(.trailing, 60)
                    .accessibilityHidden(true)
            }

            bannerCopy(item)
                .background {
                    // `fixedSize` on the copy reports the wrapped height even when
                    // the row is still the 80pt minimum, so the row can grow.
                    GeometryReader { proxy in
                        Color.clear.preference(key: BannerContentHeightKey.self, value: proxy.size.height)
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(item.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .background {
            // Outside the clip, so the shadows are not cut by it.
            Self.shadowCasters(color: item.backgroundColor)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: activateBanner)
        .onLongPressGesture(
            minimumDuration: 0.15,
            maximumDistance: 10,
            pressing: { isPressed = $0 },
            perform: {}
        )
    }

    /// Badge, title, and arrow. The title wraps in the width left of the arrow;
    /// `fixedSize` keeps that wrapped height when the row proposes less.
    private func bannerCopy(_ item: Item) -> some View {
        HStack(alignment: .center, spacing: DSConstant.small.value) {
            // `.uiSmallSemibold` (not `.uiRegular`) — a thin regular caption read too
            // faint against the bold title below it; same 13pt size, just heavier.
            VStack(alignment: .leading, spacing: DSConstant.xSmall.value) {
                if let badgeText = item.badgeText {
                    Text(badgeText)
                        .typography(.uiSmallSemibold)
                        .foregroundColor(Self.badgeTextColor)
                }
                if let title = item.title {
                    title
                        .typography(.headingMediumBold)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            if item.title != nil {
                arrowButton
            }
        }
        .padding(DSConstant.mediumLarge.value)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func activateBanner() {
        if let onBannerTap {
            onBannerTap()
        } else {
            showsUnderConstructionAlert = true
        }
    }

    /// Increment moves to the next banner, decrement to the previous.
    /// A single banner is already at both ends, so either swipe leaves it put.
    private func adjustCurrentBanner(_ direction: AccessibilityAdjustmentDirection) {
        guard let currentIndex = items.firstIndex(where: { $0.id == currentBannerID }) else { return }
        let targetIndex: Int
        switch direction {
        case .increment:
            targetIndex = currentIndex + 1
        case .decrement:
            targetIndex = currentIndex - 1
        }
        guard items.indices.contains(targetIndex) else { return }
        DSMotion.perform(reduceMotion: reduceMotion) {
            scrolledItemID = items[targetIndex].id
        }
    }

    private var currentBannerID: Item.ID? {
        scrolledItemID ?? items.first?.id
    }

    private var currentBannerAccessibilityText: Text {
        guard let item = items.first(where: { $0.id == currentBannerID }) else {
            return Text("")
        }
        return bannerAccessibilityText(for: item)
    }

    private var currentBannerPositionDescription: String {
        guard let item = items.first(where: { $0.id == currentBannerID }) else {
            return ""
        }
        return bannerPositionDescription(for: item)
    }

    private func bannerAccessibilityText(for item: Item) -> Text {
        if let accessibilityLabelOverride, !accessibilityLabelOverride.isEmpty {
            return Text(accessibilityLabelOverride)
        }
        switch (item.badgeText, item.title) {
        case let (badge?, title?):
            return Text(badge) + Text(", ") + title
        case let (badge?, nil):
            return Text(badge)
        case let (nil, title?):
            return title
        case (nil, nil):
            return Text("")
        }
    }

    private func bannerPositionDescription(for item: Item) -> String {
        let position = (items.firstIndex { $0.id == item.id } ?? 0) + 1
        return DesignSystemA11y.format(
            "common.a11y.bannerPosition",
            locale: locale,
            position,
            items.count
        )
    }

    /// Decorative only — the arrow itself has no separate action; tapping it (like
    /// anywhere else on the banner) triggers the same under-construction alert.
    private var arrowButton: some View {
        Circle()
            .fill(Color.white.opacity(0.15))
            .frame(width: Self.arrowButtonDiameter, height: Self.arrowButtonDiameter)
            .overlay {
                DSIconView(icon: .arrowRight, size: Self.arrowIconSize, color: .white)
            }
            .accessibilityHidden(true)
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
        // Reduce Motion snaps the active pill to its end width instead of easing.
        .animation(DSMotion.animation(.default, reduceMotion: reduceMotion), value: selectedIndex)
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
                    .frame(width: Self.indicatorActiveWidth * displayedProgress)
                    .animation(
                        DSMotion.animation(.linear(duration: Self.tickInterval), reduceMotion: reduceMotion),
                        value: displayedProgress
                    )
            }
        }
        .frame(
            width: isActive ? Self.indicatorActiveWidth : Self.indicatorInactiveWidth,
            height: Self.indicatorHeight
        )
    }

    /// Fill drawn in the active pill. Reduce Motion snaps to the completed bar.
    private var displayedProgress: Double {
        DSMotion.indicatorProgress(reduceMotion: reduceMotion, animated: progress)
    }

    /// Re-runs from scratch whenever `scrolledItemID` changes — via SwiftUI's `.task(id:)`
    /// auto-cancellation — whether that change came from this same countdown advancing the
    /// page, or from the user manually swiping. Ticks in small steps (rather than one long
    /// animation) purely so `isPressed` can be checked before each step — freezing `progress`
    /// mid-flight while pressed, then continuing on from the same point on release.
    /// Reduce Motion draws `displayedProgress` at the completed fill; this clock is unchanged.
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

    private struct BannerContentHeightKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
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

#Preview("DSBannerCarousel — with content") {

    func title(textColor: Color) -> Text {
        Text("Buy ")
            .foregroundColor(textColor)
        + Text("1").foregroundColor(DSColor.Text.accent)
        + Text(" get ").foregroundColor(textColor)
        + Text("2").foregroundColor(DSColor.Text.accent)
        + Text(" Croissants").foregroundColor(textColor)
    }

    return DSBannerCarousel(
        items: [
            // Light fill — title is white (`Text.inverse`), same as the other two.
            .init(
                id: 0,
                backgroundColor: DSColor.Background.pink,
                image: nil,
                badgeText: "Daily Offer",
                title: title(textColor: DSColor.Text.inverse)
            ),
            .init(
                id: 1,
                backgroundColor: DSColor.Background.brown,
                image: .mockPasteryImage1,
                badgeText: "Daily Offer",
                title: title(textColor: DSColor.Text.inverse)
            ),
            .init(
                id: 2,
                backgroundColor: DSColor.Background.green,
                image: .mockPasteryImage1,
                badgeText: "Daily Offer",
                title: title(textColor: DSColor.Text.inverse)
            )
        ]
    )
    .padding(.vertical)
    .background(Color(white: 0.95))
}
