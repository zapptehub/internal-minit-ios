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

    /// `Font.custom(_:size:)` scales with the body text style, so the extra
    /// leading scales the same way: baseline-to-baseline stays 20/15 of the size.
    @ScaledMetric(relativeTo: .body) private var titleLineSpacing = DSChallengesCardList.titleLineSpacing

    /// Figma Challenge card (6143:1889) is 200 × 124; was 140.
    static let cardSize = CGSize(width: 200, height: 124)
    /// Figma Challenge card (6143:1889) corner radius 16 (not bound to a Figma variable);
    /// was the shared `DSRadius.card` (20), which stays unchanged. Both the clip and the
    /// border use it, with the same continuous corner style.
    static let cornerRadius = DSPrimitiveScale.step400.value
    static let iconCircleDiameter = DSMetric.Spacing.xxLarge
    private static let iconSize = DSMetric.Size.iconMedium
    /// Figma Croissant frame (6154:1813) is 24; the line icons (QR, drinks) stay 20.
    static let croissantIconSize = DSMetric.Size.iconLarge
    /// Figma Progress track (6154:1800): 3pt stroke, white 24% (was 4pt at 15%).
    static let iconRingLineWidth: CGFloat = 3
    static let iconRingTrackOpacity: Double = 0.24
    /// Angular gap between dashes when the ring is split by `Item.repeatCount`.
    private static let iconRingSegmentGapDegrees: Double = 24
    /// Rotates the first dash off of straight-up (12 o'clock) to roughly 2 o'clock,
    /// matching Figma.
    private static let iconRingStartRotationDegrees: Double = 45
    static let badgeIconSize = DSMetric.Size.iconSmall
    /// Figma PTS (6143:1895): 4pt horizontal, 2pt vertical padding, 4pt gap, 16pt coin,
    /// "Body/Bold/label" text (system 12 bold, line height 20) → 24pt tall, 72pt for
    /// "+45 pts". Was 4/8 horizontal, 4 vertical, 13pt semibold.
    static let badgeHorizontalPadding = DSConstant.xSmall.value
    static let badgeVerticalPadding = DSMetric.Spacing.xxSmall
    static let badgeContentSpacing = DSConstant.xSmall.value
    static let badgeTextStyle = FontType.bodyBoldLabel
    /// Figma title (6143:1898): Sharp Grotesk SmBold 20, 15pt, line height 20,
    /// tracking 0, trimmed to cap height and last baseline (was SF 17 semibold).
    static let titleStyle = FontType.headingSmall
    /// Point size of `titleStyle`. Sharp Grotesk's SwiftUI line box is the point size.
    static let titlePointSize: CGFloat = 15
    static let titleLineHeight: CGFloat = 20
    /// `.lineSpacing` that turns the 15pt line box into Figma's 20pt line height.
    static let titleLineSpacing: CGFloat = titleLineHeight - titlePointSize
    /// The card's bottom padding; descenders of the last line paint into it.
    static let titleFollowingGap = DSConstant.mediumLarge.value
    /// Figma Content (6143:1888) gap between cards: 8 (was 12).
    static let itemSpacing: CGFloat = DSConstant.small.value

    /// Figma effect style "Small" on the Challenge card (6143:1889): the shared
    /// `DSShadow.small` token, also on the Daily Offer banners.
    static let shadow = DSShadow.small

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
            .padding(.horizontal, DSCollectionHeader.horizontalInset)
        }
        // The far card shadow reaches ~44pt below the cards (y 16 − 4 + blur 32);
        // the scroll view must not cut it off.
        .scrollClipDisabled()
    }

    private func card(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Self.topRow {
                iconCircle(item.icon, repeatCount: item.repeatCount, progress: item.progress)
            } trailing: {
                Self.badge(text: item.badgeText)
            }
            Spacer(minLength: 0)
            SharpGroteskCapTrim(followingGap: Self.titleFollowingGap) {
                Text(item.title)
                    .typography(Self.titleStyle)
                    .lineSpacing(titleLineSpacing)
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
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
                    lineWidth: DSBorderWidth.standard
                )
        }
        .background {
            // Outside the clip, so the shadows are not cut by it.
            Self.shadowCasters(color: item.backgroundColor)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showsUnderConstructionAlert = true
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    /// Opaque card-shaped layers behind the card that cast Figma's two shadows. They are
    /// filled with the card's own color and hidden by it, so only the shadows show.
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
    }

    static func iconSize(for icon: DSIcon) -> CGFloat {
        icon == .croissant ? croissantIconSize : iconSize
    }

    /// Ring on the leading edge, "+N pts" pill on the trailing edge. The pill is centred
    /// vertically on the 40pt ring, like Figma (6143:1889) and Android; it used to be
    /// top-aligned, which put it about 8pt above the ring's centre.
    static let topRowAlignment = VerticalAlignment.center

    static func topRow<Leading: View, Trailing: View>(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: topRowAlignment) {
            leading()
            Spacer(minLength: 0)
            trailing()
        }
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
                DSIconView(icon: icon, size: Self.iconSize(for: icon), color: .white)
            }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private func iconRing(repeatCount: Int, progress: Int) -> some View {
        if repeatCount <= 1 {
            Circle()
                .strokeBorder(Color.white.opacity(Self.iconRingTrackOpacity), lineWidth: Self.iconRingLineWidth)
        } else {
            let segmentDegrees = 360.0 / Double(repeatCount)
            let gap = Self.iconRingSegmentGapDegrees
            ZStack {
                ForEach(0..<repeatCount, id: \.self) { index in
                    Circle()
                        .trim(from: 0, to: max(segmentDegrees - gap, 0) / 360)
                        .stroke(
                            index < progress ? Color.white : Color.white.opacity(Self.iconRingTrackOpacity),
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
    static func badge(text: String) -> some View {
        HStack(spacing: Self.badgeContentSpacing) {
            DSIconView(icon: .minitPointCoin, size: Self.badgeIconSize, renderingMode: .original)
            Text(text)
                .typography(Self.badgeTextStyle)
                .foregroundColor(.white)
        }
        .padding(.horizontal, Self.badgeHorizontalPadding)
        .padding(.vertical, Self.badgeVerticalPadding)
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
                            lineWidth: DSBorderWidth.hairline
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
