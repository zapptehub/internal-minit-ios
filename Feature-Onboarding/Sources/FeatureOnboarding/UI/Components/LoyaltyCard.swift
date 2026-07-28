import SwiftUI
import DesignSystem

/// Generic (parameterized) loyalty-card visual: a rank badge + title/subtitle, a large
/// points value, a decorative illustration that sits *behind* the foreground content
/// (including partially under the "Loyalty Card" chip), and a full-width chip pill.
///
/// Feature-local per the Task 2.1 mapping — highly bespoke/illustration-driven, no
/// design-system equivalent (`DSCard` doesn't accommodate the rank ring, large points
/// number, or bleeding illustration). `LoyaltyCardPreview` is a thin preset wrapper
/// around this for the onboarding loyalty-decision screen; a future real "my card"
/// screen can reuse this same view with live repository data instead of duplicating it.
struct LoyaltyCard: View {
    let rankTitle: String
    let rankSubtitle: String
    let points: Int
    let chipLabel: String
    /// Decorative rank-ring fill fraction (0...1). Purely marketing art for now — there
    /// is no real "rank progress" backend concept yet (see the Task 1.1 checklist).
    var rankProgress: Double = 0.75
    @Environment(\.locale) private var locale

    /// Figma default display size for the hero points number; scales with Dynamic Type.
    @ScaledMetric(relativeTo: .largeTitle) private var pointsFontSize: CGFloat = 40

    private static let cornerRadius: CGFloat = DSConstant.cardCornerRadius.value
    /// Figma spec — the card's content (header + points + chip + padding) already
    /// lands close to this at default Dynamic Type sizes; this just guarantees it
    /// never renders shorter (e.g. with a smaller locale's shorter rank subtitle).
    private static let minHeight: CGFloat = 200
    private static let badgeDiameter: CGFloat = 40
    private static let badgeDiscDiameter: CGFloat = 28
    private static let badgeIconSize: CGFloat = 18
    private static let badgeRingWidth: CGFloat = 2.5
    /// Matches `minitArmorIcon`'s own gradient dark stop (`#C91157`) so the ring's solid
    /// arc reads as the same brand pink as the glyph it surrounds.
    private static let rankAccent = Color(red: 0.788, green: 0.067, blue: 0.341)
    private static let rankTrack = Color(red: 0.969, green: 0.827, blue: 0.878)
    private static let rankDisc = Color(red: 0.984, green: 0.906, blue: 0.933)

    /// Figma display size for `minitCashPersonImage`. Drawn first in a `ZStack` so the
    /// header / points / chip sit on top of it — matching Figma where the illustration
    /// tucks partially under the loyalty-card button.
    private static let illustrationSize = CGSize(width: 205, height: 130)

    var body: some View {
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
        // Shared with `DSStatusCard` — see `dsCardShadow()`'s doc comment.
        .dsCardShadow()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: OnboardingLocalizedString.string("onboarding.a11y.loyaltyCardSummary", locale: locale),
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
    /// holding the `minitArmor` glyph — not a plain flat icon (see the Task 1.1
    /// checklist correction against the Figma reference).
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

    /// Purely decorative for now — no card/QR screen exists yet to navigate to (see the
    /// Task 1.1 checklist), so the action is a no-op until that destination lands.
    private var chip: some View {
        DSButton(
            title: chipLabel,
            type: .loyaltyCard,
            icon: .minitQrCode,
            heightStyle: .large
        ) { }
    }
}

#Preview("LoyaltyCard") {
    LoyaltyCard(
        rankTitle: "Rank Up",
        rankSubtitle: "Earn unique benefits",
        points: 1410,
        chipLabel: "Loyalty Card"
    )
    .padding()
    .background(Color(white: 0.95))
}
