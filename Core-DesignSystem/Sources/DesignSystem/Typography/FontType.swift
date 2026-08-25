import SwiftUI

public enum FontType {
    case headingLargeBold
    /// Figma "Heading/H1" (40pt, weight 600) — e.g. the login sheet's "Enter your email address".
    case headingLargeSemibold
    case headingMediumBold
    case paragraphLargeRegular
    case paragraphRegular
    case paragraphBold
    case uiLargeBold
    case uiLargeRegular
    case uiRegular
    // TODO: confirm exact size/weight from Figma Dev Mode (rate-limited during initial
    // implementation) — 13pt semibold is an approximation of the "Input/Label" text style
    // seen in the DSInputField/DSCheckbox/DSRadio screenshot spec.
    case uiSmallSemibold

    /// Exposed for the rare case where a `Font` value is needed directly (e.g. styling
    /// individual runs of an `AttributedString`). Prefer `.typography(_:)` for plain `Text`,
    /// which also applies `tracking` — a raw `Font` alone can't carry letter-spacing.
    public var font: Font {
        switch self {
        case .headingLargeBold: return DSFont.heading(size: 56)
        case .headingLargeSemibold: return DSFont.heading(size: 40)
        case .headingMediumBold: return DSFont.heading(size: 20)
        case .paragraphLargeRegular: return .system(size: 17, weight: .regular)
        case .paragraphRegular: return .system(size: 15, weight: .regular)
        case .paragraphBold: return .system(size: 15, weight: .bold)
        case .uiLargeBold: return .system(size: 17, weight: .semibold)
        case .uiLargeRegular: return .system(size: 17, weight: .regular)
        case .uiRegular: return .system(size: 13, weight: .regular)
        case .uiSmallSemibold: return .system(size: 13, weight: .semibold)
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
}

public extension View {
    func typography(_ type: FontType) -> some View {
        self.font(type.font).tracking(type.tracking)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Text("headingLargeBold").typography(.headingLargeBold)
        Text("headingLargeSemibold").typography(.headingLargeSemibold)
        Text("headingMediumBold").typography(.headingMediumBold)
        Text("paragraphLargeRegular").typography(.paragraphLargeRegular)
        Text("paragraphRegular").typography(.paragraphRegular)
        Text("paragraphBold").typography(.paragraphBold)
        Text("uiLargeBold").typography(.uiLargeBold)
        Text("uiLargeRegular").typography(.uiLargeRegular)
        Text("uiRegular").typography(.uiRegular)
        Text("uiSmallSemibold").typography(.uiSmallSemibold)
    }
    .padding()
}
