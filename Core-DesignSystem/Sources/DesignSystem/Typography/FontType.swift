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
    case uiLargeBold
    case uiLargeRegular
    case uiRegular
    // TODO: confirm exact size/weight from Figma Dev Mode (rate-limited during initial
    // implementation) — 13pt semibold is an approximation of the "Input/Label" text style
    // seen in the DSInputField/DSCheckbox/DSRadio screenshot spec.
    case uiSmallSemibold
    /// System 12 pt medium. Tracking is 0, same as `uiRegular` and `uiSmallSemibold`.
    /// `.system(size:weight:)` is the same Dynamic Type path those styles use.
    case uiCaptionMedium

    /// Exposed for the rare case where a `Font` value is needed directly (e.g. styling
    /// individual runs of an `AttributedString`). Prefer `.typography(_:)` for plain `Text`,
    /// which also applies `tracking` — a raw `Font` alone can't carry letter-spacing.
    public var font: Font {
        switch self {
        case .headingLargeBold: return DSFont.heading(size: 56)
        case .headingLargeSemibold: return DSFont.heading(size: 40)
        case .headingH2: return DSFont.heading(size: 30)
        case .headingMediumBold: return DSFont.heading(size: 20)
        case .headingSmall: return DSFont.heading(size: 15)
        case .headingSection: return DSFont.heading(size: 18)
        case .headingH4: return DSFont.heading(size: 14)
        case .paragraphLargeRegular: return .system(size: 17, weight: .regular)
        case .paragraphRegular: return .system(size: 15, weight: .regular)
        case .paragraphBold: return .system(size: 15, weight: .bold)
        case .bodyMediumSmall: return .system(size: 14, weight: .medium)
        case .bodyBoldLabel: return .system(size: 12, weight: .bold)
        case .uiLargeBold: return .system(size: 17, weight: .semibold)
        case .uiLargeRegular: return .system(size: 17, weight: .regular)
        case .uiRegular: return .system(size: 13, weight: .regular)
        case .uiSmallSemibold: return .system(size: 13, weight: .semibold)
        case .uiCaptionMedium: return .system(size: 12, weight: .medium)
        }
    }

    /// Figma letter-spacing for this style, applied by `.typography(_:)` alongside `font`.
    /// Only the large headings carry a non-zero value in Figma; every other case is `0`
    /// (SwiftUI's default), so callers no longer need their own `.tracking(_:)` afterward.
    public var tracking: CGFloat {
        switch self {
        case .headingLargeBold: return -1.68
        case .headingLargeSemibold: return -1
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
    /// hhea lineGap is not included). Body/Medium/small uses
    /// `UIFont.lineHeight` of the 14pt medium system face. Both deltas scale
    /// with the body text style, matching `.system(size:weight:)` and
    /// `Font.custom(_:size:)`.
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
        case .bodyBoldLabel:
            return FigmaLineBox(
                lineHeight: 20,
                naturalLineHeight: UIFont.systemFont(ofSize: 12, weight: .bold).lineHeight
            )
        default:
            return nil
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
        if let lineBox = type.figmaLineBox {
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
