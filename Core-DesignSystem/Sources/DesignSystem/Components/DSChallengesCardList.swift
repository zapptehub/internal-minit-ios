import SwiftUI

/// Bold section title + trailing "see all" chevron, followed by a horizontally scrollable
/// row of colored cards — each with a small icon circle, a points-style pill badge, and a
/// bold title. Built for the Home "Challenges" section, but the `Item` shape (color + icon +
/// badge copy + title) doesn't reference challenges specifically, so it's kept generic —
/// named after its one current use for now.
///
/// Tapping the chevron or any card shows the shared under-construction alert, same
/// placeholder pattern `DSCircleItemList`/`DSBannerCarousel` use — there's no real
/// "see all"/card-tap destination wired up yet.
public struct DSChallengesCardList: View {
    /// One card slot: background color, a leading icon, a trailing points-style badge, and
    /// a title. Not `Hashable` — nothing here requires it (`ForEach` only needs
    /// `Identifiable`), same rationale as `DSCircleItemList.Item`.
    public struct Item: Identifiable {
        public let id: Int
        public let backgroundColor: Color
        public let icon: DSIcon
        public let badgeText: String
        public let title: String
        /// How many times the challenge must be repeated (e.g. `4` for "...4 times") — the
        /// icon's ring is split into this many dashes so progress toward it is countable at
        /// a glance, rather than one continuous circle. `1` (the default) draws a plain,
        /// unbroken ring for challenges that aren't a repeat-count ("Buy 1 Pizza...").
        public let repeatCount: Int
        /// How many of `repeatCount` dashes are already done — those dashes draw solid
        /// white instead of the dim 15%-opacity "remaining" color. Ignored when
        /// `repeatCount` is `1` (no dashes to fill).
        public let progress: Int

        public init(
            id: Int,
            backgroundColor: Color,
            icon: DSIcon,
            badgeText: String,
            title: String,
            repeatCount: Int = 1,
            progress: Int = 0
        ) {
            self.id = id
            self.backgroundColor = backgroundColor
            self.icon = icon
            self.badgeText = badgeText
            self.title = title
            self.repeatCount = repeatCount
            self.progress = progress
        }
    }

    let title: String
    let items: [Item]

    @State private var showsUnderConstructionAlert = false

    private static let cardSize = CGSize(width: 200, height: 140)
    private static let cornerRadius: CGFloat = DSConstant.cardCornerRadius.value
    private static let iconCircleDiameter: CGFloat = 40
    private static let iconSize: CGFloat = 20
    private static let iconRingLineWidth: CGFloat = 4
    /// Angular gap between dashes when the ring is split by `Item.repeatCount`.
    private static let iconRingSegmentGapDegrees: Double = 24
    /// Rotates the first dash off of straight-up (12 o'clock) to roughly 2 o'clock,
    /// matching Figma.
    private static let iconRingStartRotationDegrees: Double = 45
    private static let badgeIconSize: CGFloat = 16
    private static let itemSpacing: CGFloat = DSConstant.medium.value

    public init(title: String, items: [Item]) {
        self.title = title
        self.items = items
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.medium.value) {
            header
            itemRow
        }
        .featureUnderConstructionAlert(isPresented: $showsUnderConstructionAlert)
    }

    private var header: some View {
        DSCollectionHeader(title: title) {
            showsUnderConstructionAlert = true
        }
    }

    private var itemRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: Self.itemSpacing) {
                ForEach(items) { item in
                    card(item)
                }
            }
            .padding(.horizontal, DSConstant.mediumLarge.value)
        }
    }

    private func card(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                iconCircle(item.icon, repeatCount: item.repeatCount, progress: item.progress)
                Spacer(minLength: 0)
                badge(text: item.badgeText)
            }
            Spacer(minLength: 0)
            Text(item.title)
                .typography(.uiLargeBold)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(DSConstant.mediumLarge.value)
        .frame(width: Self.cardSize.width, height: Self.cardSize.height, alignment: .topLeading)
        .background(item.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            // Subtle top-to-bottom light-to-dark hairline, matching Figma's
            // "#FFFFFF3D" → "#0000001F" gradient border layered over the card.
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.239), Color.black.opacity(0.122)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showsUnderConstructionAlert = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Outlined ring, not a filled circle — matches Figma's thin white 15%-opacity stroke
    /// around the glyph, rather than `DSBannerCarousel`'s filled `arrowButton` convention.
    /// Split into `repeatCount` even dashes (with a gap between each) when it's a
    /// repeat-count challenge, so the number of times done vs. left is countable — with
    /// `progress` of those dashes drawn solid white to mark them as already done.
    private func iconCircle(_ icon: DSIcon, repeatCount: Int, progress: Int) -> some View {
        iconRing(repeatCount: repeatCount, progress: progress)
            .frame(width: Self.iconCircleDiameter, height: Self.iconCircleDiameter)
            .overlay {
                DSIconView(icon: icon, size: Self.iconSize, color: .white)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func iconRing(repeatCount: Int, progress: Int) -> some View {
        if repeatCount <= 1 {
            Circle()
                .strokeBorder(Color.white.opacity(0.15), lineWidth: Self.iconRingLineWidth)
        } else {
            let segmentDegrees = 360.0 / Double(repeatCount)
            let gap = Self.iconRingSegmentGapDegrees
            ZStack {
                ForEach(0..<repeatCount, id: \.self) { index in
                    Circle()
                        .trim(from: 0, to: max(segmentDegrees - gap, 0) / 360)
                        .stroke(
                            index < progress ? Color.white : Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: Self.iconRingLineWidth, lineCap: .round)
                        )
                        .rotationEffect(
                            .degrees(-90 + Self.iconRingStartRotationDegrees + gap / 2 + Double(index) * segmentDegrees)
                        )
                }
            }
        }
    }

    /// Light "liquid glass" pill — a frosted `.thinMaterial` fill (tinted by whatever's
    /// behind it, i.e. the card's own color) plus a bright hairline rim, rather than a flat
    /// dark chip. Reuses the "+N pts" icon (`DSIcon.minitPointCoin`) already used for
    /// notification rows.
    private func badge(text: String) -> some View {
        HStack(spacing: DSConstant.xSmall.value) {
            DSIconView(icon: .minitPointCoin, size: Self.badgeIconSize, renderingMode: .original)
            Text(text)
                .typography(.uiSmallSemibold)
                .foregroundColor(.white)
        }
        .padding(.leading, DSConstant.xSmall.value)
        .padding(.trailing, DSConstant.small.value)
        .padding(.vertical, DSConstant.xSmall.value)
        .background {
            Capsule()
                .fill(.thinMaterial)
                .overlay {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), Color.white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

#Preview("DSChallengesCardList") {
    DSChallengesCardList(
        title: "Challenges",
        items: [
            .init(
                id: 0,
                backgroundColor: DSColor.Background.orange,
                icon: .qrScanLine,
                badgeText: "+45 pts",
                title: "Use the minit loyalty card 4 times",
                repeatCount: 4,
                progress: 0
            ),
            .init(
                id: 1,
                backgroundColor: DSColor.Background.green,
                icon: .croissant,
                badgeText: "+45 pts",
                title: "Buy 1 Pizza or any other type of bakery"
            ),
            .init(
                id: 2,
                backgroundColor: DSColor.Background.pink,
                icon: .coffeeCup,
                badgeText: "+25 pts",
                title: "Add a Coffee to your morning breakfast"
            ),
            .init(
                id: 3,
                backgroundColor: DSColor.Background.brown,
                icon: .croissant,
                badgeText: "+45 pts",
                title: "Taste multiple Minit bakery types",
                repeatCount: 4,
                progress: 1
            )
        ]
    )
    .padding(.vertical)
    .background(Color(white: 1))
}
