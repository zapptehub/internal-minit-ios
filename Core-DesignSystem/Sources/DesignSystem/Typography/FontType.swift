import SwiftUI
import UIKit

public enum FontType {
    case headingLargeBold
    /// Figma "Heading/H1" (Sharp Grotesk SmBold 20, 40pt, weight 600, line height 44, tracking −1).
    case headingLargeSemibold
    /// Figma "Heading/H2" (Home greeting): Sharp Grotesk SmBold 20, 30pt, weight 600,
    /// tracking 0, line height "normal" — a 38pt box at 30pt (Figma's normal line
    /// includes the face's hhea line gap).
    case headingH2
    case headingMediumBold
    /// Figma loyalty card popup title (6078:5066): Sharp Grotesk SmBold 20, 32pt,
    /// tracking −1, line height "normal", text-box trim both (cap to alphabetic). The
    /// trim is `SharpGroteskCapTrim` at the call site (`LoyaltyCardDetailView`).
    case headingPopupTitle
    /// Figma Challenges card title (6143:1898): Sharp Grotesk SmBold 20, 15pt,
    /// line height 20, tracking 0, text-box trim both (cap to alphabetic).
    /// The line height and the trim are applied at the call site with
    /// `.lineSpacing` and `SharpGroteskCapTrim`, like `DSStatusCard`'s title.
    case headingSmall
    /// Figma Home section title (Products 6154:1940, Challenges 6143:1976, News & Recipes
    /// 6154:2057): Sharp Grotesk SmBold 20, 18pt, line height "normal", tracking 0,
    /// text-box trim both (cap to alphabetic). The trim is `SharpGroteskCapTrim` at the
    /// call site (`DSCollectionHeader`), so no Figma line box is applied here.
    case headingSection
    /// Figma "Heading/H4" (News & Recipes card title 6154:2046): Sharp Grotesk SmBold 20,
    /// 14pt, line height 18, tracking 0, text-box trim both (cap to alphabetic). The line
    /// height and the trim are applied at the call site with `.lineSpacing` and
    /// `SharpGroteskCapTrim` (`DSMediaCardList`), like `headingSmall`.
    case headingH4
    case paragraphLargeRegular
    case paragraphRegular
    case paragraphBold
    /// Figma "Body/Medium/small": system 14 medium, line height 20, tracking 0.
    case bodyMediumSmall
    /// Figma "Body/Bold/label" (Challenges "+N pts" pill): system 12 bold, line height 20,
    /// tracking 0.
    case bodyBoldLabel
    /// Figma "Body/Bold/md": system 16 bold, line height 20, tracking 0 (loyalty card
    /// popup button label 6078:5103).
    case bodyBoldMedium
    case uiLargeBold
    case uiLargeRegular
    case uiRegular
    // TODO: confirm exact size/weight from Figma Dev Mode (rate-limited during initial
    // implementation) — 13pt semibold is an approximation of the "Input/Label" text style
    // seen in the DSInputField/DSCheckbox/DSRadio screenshot spec.
    case uiSmallSemibold
    /// System 12 pt medium. Tracking is 0, same as `uiRegular` and `uiSmallSemibold`.
    /// `.system(size:weight:)` is a fixed design size. `.typography(_:)` scales it
    /// with the body text style and no cap, the same way Android `sp` scales.
    case uiCaptionMedium

    /// Design-size face. System styles here are fixed `.system(size:weight:)` values —
    /// that initializer does **not** follow Dynamic Type. Prefer `.typography(_:)`, which
    /// scales those styles with `UIFontMetrics` for `.body` and no cap. Sharp Grotesk
    /// headings already scale via `Font.custom`. A raw `Font` also can't carry tracking.
    public var font: Font {
        switch self {
        case .headingLargeBold: return DSFont.heading(size: 56)
        case .headingLargeSemibold: return DSFont.heading(size: 40)
        case .headingH2: return DSFont.heading(size: 30)
        case .headingMediumBold: return DSFont.heading(size: 20)
        case .headingPopupTitle: return DSFont.heading(size: 32)
        case .headingSmall: return DSFont.heading(size: 15)
        case .headingSection: return DSFont.heading(size: 18)
        case .headingH4: return DSFont.heading(size: 14)
        case .paragraphLargeRegular: return .system(size: 17, weight: .regular)
        case .paragraphRegular: return .system(size: 15, weight: .regular)
        case .paragraphBold: return .system(size: 15, weight: .bold)
        case .bodyMediumSmall: return .system(size: 14, weight: .medium)
        case .bodyBoldLabel: return .system(size: 12, weight: .bold)
        case .bodyBoldMedium: return .system(size: 16, weight: .bold)
        case .uiLargeBold: return .system(size: 17, weight: .semibold)
        case .uiLargeRegular: return .system(size: 17, weight: .regular)
        case .uiRegular: return .system(size: 13, weight: .regular)
        case .uiSmallSemibold: return .system(size: 13, weight: .semibold)
        case .uiCaptionMedium: return .system(size: 12, weight: .medium)
        }
    }

    /// Design size at the default content size. Headings and system styles share this
    /// so a too-wide word can be fitted without changing the `.large` face.
    var designPointSize: CGFloat {
        switch self {
        case .headingLargeBold: return 56
        case .headingLargeSemibold: return 40
        case .headingH2: return 30
        case .headingMediumBold: return 20
        case .headingPopupTitle: return 32
        case .headingSmall: return 15
        case .headingSection: return 18
        case .headingH4: return 14
        case .paragraphLargeRegular: return 17
        case .paragraphRegular, .paragraphBold: return 15
        case .bodyMediumSmall: return 14
        case .bodyBoldLabel: return 12
        case .bodyBoldMedium: return 16
        case .uiLargeBold, .uiLargeRegular: return 17
        case .uiRegular, .uiSmallSemibold: return 13
        case .uiCaptionMedium: return 12
        }
    }

    /// Figma letter-spacing for this style, applied by `.typography(_:)` alongside `font`.
    /// Only the large headings carry a non-zero value in Figma; every other case is `0`
    /// (SwiftUI's default), so callers no longer need their own `.tracking(_:)` afterward.
    public var tracking: CGFloat {
        switch self {
        case .headingLargeBold: return -1.68
        case .headingLargeSemibold: return -1
        case .headingPopupTitle: return -1
        default: return 0
        }
    }

    /// Figma line box, when it is taller than the font's own line.
    ///
    /// SwiftUI `Font` cannot carry a line height. `.lineSpacing` only inserts
    /// space between lines (the status-card title does `23 − 20` the same way).
    /// The half of that extra leading is also applied above the first line and
    /// below the last, which is Figma's CSS line-height model: a single line's
    /// box is the Figma line height, and a two-line Heading/H1 box is 88.
    ///
    /// Sharp Grotesk's line box is the point size (`ascender − descender`;
    /// hhea lineGap is not included). Body styles use `UIFont.lineHeight` of
    /// the system face at the design size. `.typography` scales system faces
    /// with the body text style, and these deltas scale the same way
    /// (`@ScaledMetric` relative to `.body`), matching `Font.custom(_:size:)`.
    var figmaLineBox: FigmaLineBox? {
        switch self {
        case .headingLargeSemibold:
            return FigmaLineBox(lineHeight: 44, naturalLineHeight: 40)
        case .headingH2:
            return FigmaLineBox(lineHeight: 38, naturalLineHeight: 30)
        case .bodyMediumSmall:
            return FigmaLineBox(
                lineHeight: 20,
                naturalLineHeight: UIFont.systemFont(ofSize: 14, weight: .medium).lineHeight
            )
        case .bodyBoldMedium:
            return FigmaLineBox(
                lineHeight: 20,
                naturalLineHeight: UIFont.systemFont(ofSize: 16, weight: .bold).lineHeight
            )
        case .bodyBoldLabel:
            return FigmaLineBox(
                lineHeight: 20,
                naturalLineHeight: UIFont.systemFont(ofSize: 12, weight: .bold).lineHeight
            )
        default:
            return nil
        }
    }

    /// System faces that must scale like Android `sp`: linear with the body
    /// text style, including accessibility sizes, with no maximum.
    /// Headings are absent — `Font.custom` already scales those.
    var systemFontSpec: SystemFontSpec? {
        switch self {
        case .paragraphLargeRegular: return SystemFontSpec(size: 17, weight: .regular)
        case .paragraphRegular: return SystemFontSpec(size: 15, weight: .regular)
        case .paragraphBold: return SystemFontSpec(size: 15, weight: .bold)
        case .bodyMediumSmall: return SystemFontSpec(size: 14, weight: .medium)
        case .bodyBoldLabel: return SystemFontSpec(size: 12, weight: .bold)
        case .bodyBoldMedium: return SystemFontSpec(size: 16, weight: .bold)
        case .uiLargeBold: return SystemFontSpec(size: 17, weight: .semibold)
        case .uiLargeRegular: return SystemFontSpec(size: 17, weight: .regular)
        case .uiRegular: return SystemFontSpec(size: 13, weight: .regular)
        case .uiSmallSemibold: return SystemFontSpec(size: 13, weight: .semibold)
        case .uiCaptionMedium: return SystemFontSpec(size: 12, weight: .medium)
        default: return nil
        }
    }

    /// System font scaled for `dynamicTypeSize`. At `.large` this is the design
    /// size in `font`. `nil` for Sharp Grotesk headings.
    public func scaledSystemFont(for dynamicTypeSize: DynamicTypeSize) -> Font? {
        guard let spec = systemFontSpec else { return nil }
        return spec.font(for: dynamicTypeSize)
    }
}

struct SystemFontSpec {
    let size: CGFloat
    let weight: Font.Weight

    func font(for dynamicTypeSize: DynamicTypeSize) -> Font {
        let traits = UITraitCollection(preferredContentSizeCategory: dynamicTypeSize.uiContentSizeCategory)
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: size, compatibleWith: traits)
        return .system(size: scaled, weight: weight)
    }
}

extension DynamicTypeSize {
    var uiContentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .large
        }
    }
}

/// Extra leading that turns a font's own line box into a Figma line height.
struct FigmaLineBox {
    let lineHeight: CGFloat
    /// The face's own line box at the style's point size, before Dynamic Type.
    let naturalLineHeight: CGFloat

    /// What `.lineSpacing` adds between line boxes. `lineHeight − natural`.
    var lineSpacing: CGFloat { max(0, lineHeight - naturalLineHeight) }

    /// Half of [lineSpacing], painted above the first line and below the last.
    var halfLeading: CGFloat { lineSpacing / 2 }
}

public extension View {
    @ViewBuilder
    func typography(_ type: FontType) -> some View {
        if let spec = type.systemFontSpec {
            modifier(
                ScaledSystemFontModifier(
                    spec: spec,
                    tracking: type.tracking,
                    lineBox: type.figmaLineBox
                )
            )
        } else if let lineBox = type.figmaLineBox {
            self.font(type.font)
                .tracking(type.tracking)
                .modifier(
                    FigmaLineBoxModifier(
                        lineSpacing: lineBox.lineSpacing,
                        halfLeading: lineBox.halfLeading
                    )
                )
        } else {
            self.font(type.font).tracking(type.tracking)
        }
    }
}

/// Scales a system design size with the body text style. `@ScaledMetric` has no
/// accessibility cap, matching Android `sp`. At the default content size the
/// metric is the design size, so `.system(size:weight:)` is unchanged.
private struct ScaledSystemFontModifier: ViewModifier {
    let weight: Font.Weight
    let tracking: CGFloat
    let lineBox: FigmaLineBox?
    @ScaledMetric private var size: CGFloat

    init(spec: SystemFontSpec, tracking: CGFloat, lineBox: FigmaLineBox?) {
        self.weight = spec.weight
        self.tracking = tracking
        self.lineBox = lineBox
        _size = ScaledMetric(wrappedValue: spec.size, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        let styled = content
            .font(.system(size: size, weight: weight))
            .tracking(tracking)
        if let lineBox {
            styled.modifier(
                FigmaLineBoxModifier(
                    lineSpacing: lineBox.lineSpacing,
                    halfLeading: lineBox.halfLeading
                )
            )
        } else {
            styled
        }
    }
}

/// Applies Figma half-leading. `.lineSpacing` does not pad a single line, so
/// the vertical padding is what makes that line's box match the line height.
private struct FigmaLineBoxModifier: ViewModifier {
    @ScaledMetric private var lineSpacing: CGFloat
    @ScaledMetric private var halfLeading: CGFloat

    init(lineSpacing: CGFloat, halfLeading: CGFloat) {
        _lineSpacing = ScaledMetric(wrappedValue: lineSpacing, relativeTo: .body)
        _halfLeading = ScaledMetric(wrappedValue: halfLeading, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        content
            .lineSpacing(lineSpacing)
            .padding(.vertical, halfLeading)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Text("headingLargeBold").typography(.headingLargeBold)
        Text("headingLargeSemibold").typography(.headingLargeSemibold)
        Text("headingH2").typography(.headingH2)
        Text("headingMediumBold").typography(.headingMediumBold)
        Text("headingSmall").typography(.headingSmall)
        Text("headingSection").typography(.headingSection)
        Text("headingH4").typography(.headingH4)
        Text("paragraphLargeRegular").typography(.paragraphLargeRegular)
        Text("paragraphRegular").typography(.paragraphRegular)
        Text("paragraphBold").typography(.paragraphBold)
        Text("bodyMediumSmall").typography(.bodyMediumSmall)
        Text("bodyBoldLabel").typography(.bodyBoldLabel)
        Text("uiLargeBold").typography(.uiLargeBold)
        Text("uiLargeRegular").typography(.uiLargeRegular)
        Text("uiRegular").typography(.uiRegular)
        Text("uiSmallSemibold").typography(.uiSmallSemibold)
        Text("uiCaptionMedium").typography(.uiCaptionMedium)
    }
    .padding()
}
