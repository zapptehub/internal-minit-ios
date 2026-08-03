import SwiftUI

/// Parameterized loyalty-card visual: rank badge + title/subtitle, large points value,
/// decorative illustration behind foreground content, and a full-width chip pill.
///
/// Used by onboarding's marketing preview and Home's live (currently hardcoded) card.
public struct LoyaltyCard: View {
    let rankTitle: String
    let rankSubtitle: String
    let points: Int
    let chipLabel: String
    /// Decorative rank-ring fill fraction (0...1). Purely marketing art for now — there
    /// is no real "rank progress" backend concept yet.
    var rankProgress: Double = 0.75
    /// Home sits the card on a solid orange field where the shared card shadow reads too
    /// heavy; onboarding keeps the default shadow over the gradient.
    var showsShadow: Bool = true
    /// Tapping the chip is a no-op until a real destination exists (e.g. onboarding's
    /// marketing preview); Home passes a closure that presents the full-screen QR detail.
    var onChipTap: (() -> Void)?
    @Environment(\.locale) private var locale

    /// Figma default display size for the hero points number; scales with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var pointsFontSize: CGFloat = 40

    private static let cornerRadius: CGFloat = DSConstant.cardCornerRadius.value
    /// Figma spec — the card's content (header + points + chip + padding) already
    /// lands close to this at default Dynamic Type sizes; this just guarantees it
    /// never renders shorter (e.g. with a smaller locale's shorter rank subtitle).
    private static let minHeight: CGFloat = 200
    private static let badgeDiameter: CGFloat = 40
    private static let badgeIconSize: CGFloat = 18
    private static let badgeRingWidth: CGFloat = 2.5
    /// Matches `minitArmorIcon`'s own gradient dark stop (`#C91157`) so the ring's solid
    /// arc reads as the same brand pink as the glyph it surrounds.
    private static let rankAccent = Color(red: 0.788, green: 0.067, blue: 0.341)
    private static let rankTrack = Color(red: 0.969, green: 0.827, blue: 0.878)

    /// Figma display size for `minitCashPersonImage`. Drawn first in a `ZStack` so the
    /// header / points / chip sit on top of it — matching Figma where the illustration
    /// tucks partially under the loyalty-card button.
    private static let illustrationSize = CGSize(width: 205, height: 130)

    public init(
        rankTitle: String,
        rankSubtitle: String,
        points: Int,
        chipLabel: String,
        rankProgress: Double = 0.75,
        showsShadow: Bool = true,
        onChipTap: (() -> Void)? = nil
    ) {
        self.rankTitle = rankTitle
        self.rankSubtitle = rankSubtitle
        self.points = points
        self.chipLabel = chipLabel
        self.rankProgress = rankProgress
        self.showsShadow = showsShadow
        self.onChipTap = onChipTap
    }

    public var body: some View {
        // `.topTrailing` + matching top padding aligns the illustration's top edge
        // with the header row (instead of centering across the whole card, which sat
        // too low) while keeping it flush against the trailing edge — its bottom
        // portion still tucks behind the chip lower down, matching Figma.
        ZStack(alignment: .topTrailing) {
            // `.fill` — the source asset's native aspect ratio (197:169) is narrower
            // than the 226x147 display box, so `.fit` (the default) was letterboxing
            // it and leaving visible transparent margins on both sides.
            DSImageView(image: .minitCashPerson, size: Self.illustrationSize, contentMode: .fill)
                .padding(.top, DSConstant.mediumLarge.value)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSConstant.medium.value) {
                header
                pointsText
                chip
            }
            .padding(DSConstant.mediumLarge.value)
        }
        .frame(maxWidth: .infinity, minHeight: Self.minHeight, alignment: .leading)
        .background(DSColor.Background.Layer.level0)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .modifier(LoyaltyCardShadowModifier(isEnabled: showsShadow))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: DesignSystemLocalizedString.string("common.a11y.loyaltyCardSummary", locale: locale),
                rankTitle,
                rankSubtitle,
                Self.pointsString(points)
            )
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DSConstant.small.value) {
            rankBadge

            VStack(alignment: .leading, spacing: 2) {
                Text(rankTitle)
                    .typography(.headingMediumBold)
                    .foregroundColor(DSColor.Text.heading)

                Text(rankSubtitle)
                    .typography(.uiRegular)
                    .foregroundColor(DSColor.Text.secondary)
            }
        }
    }

    /// Pale dashed track + solid brand-pink progress arc behind a small filled disc
    /// holding the `minitArmor` glyph.
    private var rankBadge: some View {
        ZStack {
            Circle()
                .stroke(Self.rankTrack, style: StrokeStyle(lineWidth: Self.badgeRingWidth, dash: [6, 3]))

            Circle()
                .trim(from: 0, to: rankProgress)
                .stroke(Self.rankAccent, style: StrokeStyle(lineWidth: Self.badgeRingWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            DSIconView(icon: .minitArmor, size: Self.badgeIconSize, renderingMode: .original)
        }
        .frame(width: Self.badgeDiameter, height: Self.badgeDiameter)
        .accessibilityHidden(true)
    }

    /// Large "display number" size, not a standard `FontType` token — a one-off hero
    /// number specific to this card. `@ScaledMetric` keeps the Figma 40pt look at the
    /// default size while respecting Dynamic Type. Thousands are separated with a
    /// literal comma (e.g. `1,410`) to match Figma — not locale-dependent.
    private var pointsText: some View {
        Text(Self.pointsString(points))
            .font(.system(size: pointsFontSize, weight: .black))
            .foregroundColor(DSColor.Text.heading)
            .accessibilityHidden(true)
    }

    /// Inserts a comma every three digits from the right (`1410` → `"1,410"`).
    private static func pointsString(_ value: Int) -> String {
        let digits = String(value)
        var result = ""
        for (offset, character) in digits.reversed().enumerated() {
            if offset > 0, offset % 3 == 0 {
                result.append(",")
            }
            result.append(character)
        }
        return String(result.reversed())
    }

    private var chip: some View {
        DSButton(
            title: chipLabel,
            type: .loyaltyCard,
            icon: .minitQrCode,
            heightStyle: .large
        ) {
            onChipTap?()
        }
    }
}

private struct LoyaltyCardShadowModifier: ViewModifier {
    let isEnabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.dsCardShadow()
        } else {
            content
        }
    }
}

#Preview("LoyaltyCard") {
    LoyaltyCard(
        rankTitle: "Silver",
        rankSubtitle: "540 pts until Platinum",
        points: 3210,
        chipLabel: "Minit Card"
    )
    .padding()
    .background(Color(white: 0.95))
}
