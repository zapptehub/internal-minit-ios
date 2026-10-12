import SwiftUI
import UIKit

/// Parameterized loyalty-card visual: rank badge + title/subtitle, large points value,
/// decorative illustration behind foreground content, and a full-width chip pill.
///
/// Used by onboarding's marketing preview and Home's live (currently hardcoded) card.
/// Text follows Figma node 6166:3315 (Points).
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
    /// Chip tap, and the summary's VoiceOver action when non-nil. Nil on the
    /// onboarding marketing preview, so the summary stays a label; Home presents
    /// the full-screen QR detail.
    var onChipTap: (() -> Void)?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let cornerRadius: CGFloat = DSConstant.cardCornerRadius.value
    /// Figma card height. Cap-trimmed heading boxes plus the 20pt section gap
    /// land on this at the default content size; larger Dynamic Type may grow it.
    private static let minHeight: CGFloat = 200
    private static let badgeDiameter: CGFloat = 40
    private static let badgeIconSize: CGFloat = 18
    private static let badgeRingWidth: CGFloat = 2.5
    private static let rankAccent = DSSemanticColor.Brand.secondary.color
    private static let rankTrack = DSSemanticColor.Brand.secondarySubtle.color

    /// Display size for `minitCardPersonImage`. Drawn first in a `ZStack` so the
    /// header / points / chip sit on top of it — matching Figma where the illustration
    /// tucks partially under the loyalty-card button. Portrait box (vs. the old
    /// `minitCashPerson` landscape one) to match this asset's ~381:474 native aspect.
    private static let illustrationSize = CGSize(width: 127, height: 158)

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
        // `.topTrailing` + top/trailing padding pins the illustration to the header
        // row's vertical band and insets it 28pt from the card's right edge — its
        // bottom portion still tucks behind the chip lower down, matching Figma.
        ZStack(alignment: .topTrailing) {
            // `illustrationSize` already matches this asset's native aspect ratio, so
            // `.fit` shows the whole illustration without cropping. Near-zero top
            // padding — the person's head sits almost flush with the card's top edge.
            DSImageView(image: .minitCardPerson, size: Self.illustrationSize, contentMode: .fit)
                .padding(.top, DSConstant.xSmall.value)
                .padding(.trailing, 28)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: LoyaltyCardMetrics.sectionSpacing) {
                summary
                chip
            }
            .padding(DSConstant.mediumLarge.value)
        }
        .frame(maxWidth: .infinity, minHeight: Self.minHeight, alignment: .leading)
        .background(DSColor.Background.Layer.level0)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .modifier(LoyaltyCardShadowModifier(isEnabled: showsShadow))
    }

    /// Rank, subtitle, and points as one element, separate from the chip.
    /// VoiceOver treats it as a button that runs `onChipTap` only when that
    /// closure is set. Finger taps stay on the chip only.
    private var summary: some View {
        VStack(alignment: .leading, spacing: LoyaltyCardMetrics.sectionSpacing) {
            header
            pointsText
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryAccessibilityLabel)
        .modifier(LoyaltyCardSummaryAccessibilityModifier(action: onChipTap))
    }

    private var summaryAccessibilityLabel: String {
        String(
            format: DesignSystemLocalizedString.string("common.a11y.loyaltyCardSummary", locale: locale),
            rankTitle,
            rankSubtitle,
            Self.pointsString(points)
        )
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DSConstant.small.value) {
            rankBadge

            VStack(alignment: .leading, spacing: LoyaltyCardMetrics.rankSubtitleSpacing) {
                if dynamicTypeSize > .large {
                    // "Silver" is one word in a narrow column. Fitting the line
                    // keeps it whole; the default size still uses the cap-trimmed title.
                    Text(rankTitle)
                        .font(DSFont.heading(size: LoyaltyCardMetrics.rankTitleFontSize))
                        .foregroundColor(DSColor.Text.heading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.3)
                } else {
                    SharpGroteskCapTrim(followingGap: LoyaltyCardMetrics.rankSubtitleSpacing) {
                        Text(rankTitle)
                            .typography(LoyaltyCardMetrics.rankTitleStyle)
                            .foregroundColor(DSColor.Text.heading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text(rankSubtitle)
                    .typography(LoyaltyCardMetrics.subtitleStyle)
                    .foregroundColor(LoyaltyCardMetrics.rankSubtitleColor)
                    .lineLimit(dynamicTypeSize > .large ? nil : 2)
            }
            .padding(.trailing, LoyaltyCardMetrics.illustrationClearance)
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

    /// `headingLargeBold` (Sharp Grotesk 56, tracking −1.68). Figma’s points are
    /// the same size with tracking −1; the style is 0.68 tighter. Trailing
    /// clearance plus `minimumScaleFactor` keeps the number off the illustration.
    private var pointsText: some View {
        SharpGroteskCapTrim(followingGap: LoyaltyCardMetrics.sectionSpacing) {
            Text(Self.pointsString(points))
                .typography(LoyaltyCardMetrics.pointsStyle)
                .foregroundColor(DSColor.Text.heading)
                .lineLimit(1)
                .minimumScaleFactor(LoyaltyCardMetrics.pointsMinimumScaleFactor)
        }
        .padding(.trailing, LoyaltyCardMetrics.illustrationClearance)
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

/// Loyalty-card text uses existing `FontType` styles. Figma sizes that are not
/// on that scale take the nearest style. Internal so tests can assert the choice.
enum LoyaltyCardMetrics {
    /// Figma 56 / tracking −1. `headingLargeBold` is 56 / −1.68.
    static let pointsStyle = FontType.headingLargeBold
    /// Figma Sharp Grotesk 18. `headingMediumBold` is 20 (+2).
    static let rankTitleStyle = FontType.headingMediumBold
    /// Figma system medium 12. `uiCaptionMedium` is system medium 12.
    static let subtitleStyle = FontType.uiCaptionMedium
    /// Figma system bold 16. `paragraphBold` is system bold 15 (−1).
    static let chipLabelStyle = FontType.paragraphBold
    /// Nominal point sizes of `pointsStyle` and `rankTitleStyle`. Cap trim does
    /// not read these; it measures the font SwiftUI actually resolved.
    static let pointsFontSize: CGFloat = 56
    static let rankTitleFontSize: CGFloat = 20
    /// Figma gap between the rank title and "Earn unique benefits".
    /// `DSConstant.smallMedium` is that 6pt step.
    static let rankSubtitleSpacing: CGFloat = DSConstant.smallMedium.value
    /// Figma vertical gap between the rank block, the points, and the chip.
    static let sectionSpacing: CGFloat = 20
    static let chipIconSize: CGFloat = 24
    /// Same 8pt as `DSConstant.small`; named here so the chip stays card-local
    /// if the shared button gap ever changes.
    static let chipIconGap: CGFloat = 8
    /// Shrinks the points number before it would run through the illustration
    /// or clip at accessibility sizes. Default content size does not shrink:
    /// "1,410" at 56pt is narrower than the space left of the artwork.
    static let pointsMinimumScaleFactor: CGFloat = 0.45
    /// Keeps text clear of the illustration's opaque pixels.
    /// 127 artwork + 28 trailing inset − 16 content padding − 10 transparent
    /// leading edge of `minitCardPerson` (30/381 of the 127pt box).
    static let illustrationClearance: CGFloat = 129
    /// `#A3A3A3`. No `DSColor` text role matches; see `loyaltyRankSubtitle`.
    static let rankSubtitleColor = DSPlatformColorExtension.loyaltyRankSubtitle.color
}

/// Cap height ÷ ascender for the bundled Sharp Grotesk face.
///
/// The ratio is constant across sizes. Callers scale it by the baseline of the
/// `Text` SwiftUI actually laid out, which already includes Dynamic Type and
/// `minimumScaleFactor`.
enum SharpGroteskFontMetrics {
    static let postScriptName = "SharpGroteskSmBold20-Regular"

    static let capHeightPerAscender: CGFloat = {
        let font = uiFont(pointSize: 20)
        return font.capHeight / font.ascender
    }()

    static func uiFont(pointSize: CGFloat) -> UIFont {
        _ = DSFont.heading(size: pointSize)
        guard let font = UIFont(name: postScriptName, size: pointSize) else {
            preconditionFailure("Missing \(postScriptName)")
        }
        return font
    }
}

/// Pulls a Sharp Grotesk line down to the cap height of the resolved font.
///
/// Figma's text box is the cap height (40pt at 56pt). `UIFont.lineHeight` for
/// this face is `ascender − descender`; `leading` (hhea lineGap 275/1000) is
/// reported but not included, and SwiftUI's `Text` uses that same line box
/// (20pt at 20pt, ~56.3pt at 56pt). Subtracting `descent + leading` from it
/// lifts the baseline by ~0.275×size (5.5pt at 20, 15.4pt at 56) and eats the
/// gap under the title and the points.
///
/// Descenders paint into `followingGap`. When the resolved descent is taller
/// than that gap, the box grows by the overflow so the next row starts at the
/// descent instead of covering the glyph.
///
/// A single line trims to the cap height, which is what the loyalty card uses.
/// A wrapped title keeps the span from the first baseline to the last, so the
/// box runs from the first cap to the last alphabetic baseline (Figma
/// text-box-trim both) and only the last line's descent uses `followingGap`.
struct SharpGroteskCapTrim: Layout {
    var followingGap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        let dims = subview.dimensions(in: childProposal(proposal))
        let resolved = resolvedBox(dims)
        return CGSize(width: dims.width, height: resolved.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        let proposal = childProposal(proposal)
        let dims = subview.dimensions(in: proposal)
        let resolved = resolvedBox(dims)
        subview.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + resolved.cap - resolved.baseline),
            proposal: proposal
        )
    }

    func explicitAlignment(
        of guide: VerticalAlignment,
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGFloat? {
        guard guide == .firstTextBaseline, let subview = subviews.first else { return nil }
        let dims = subview.dimensions(in: childProposal(proposal))
        return resolvedBox(dims).cap
    }

    private func childProposal(_ proposal: ProposedViewSize) -> ProposedViewSize {
        ProposedViewSize(width: proposal.width, height: nil)
    }

    private func resolvedBox(_ dims: ViewDimensions) -> (cap: CGFloat, baseline: CGFloat, height: CGFloat) {
        let baseline = dims[VerticalAlignment.firstTextBaseline]
        guard baseline > 1 else {
            return (dims.height, dims.height, dims.height)
        }
        let cap = baseline * SharpGroteskFontMetrics.capHeightPerAscender
        let last = dims[VerticalAlignment.lastTextBaseline]
        // Single-line text reports the same guide twice. Treating a later
        // last baseline as extra descent would put that descent back in the box.
        let lineSpan = last > baseline + 0.5 ? last - baseline : 0
        let descentAnchor = lineSpan > 0 ? last : baseline
        let belowAnchor = max(0, dims.height - descentAnchor)
        let overflow = max(0, belowAnchor - followingGap)
        return (cap, baseline, cap + lineSpan + overflow)
    }
}

/// Button trait and default VoiceOver action only when Home supplies `onChipTap`.
/// The onboarding preview leaves the closure nil, so the summary is a label.
private struct LoyaltyCardSummaryAccessibilityModifier: ViewModifier {
    let action: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let action {
            content
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(.default, action)
        } else {
            content
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
