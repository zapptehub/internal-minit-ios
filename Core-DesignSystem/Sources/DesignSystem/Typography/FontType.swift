import SwiftUI

public enum FontType {
    // TODO: replace system fallback with "Sharp Grotesk SmBold 20" once the font file is added to the project.
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
    /// individual runs of an `AttributedString`). Prefer `.typography(_:)` for plain `Text`.
    public var font: Font {
        switch self {
        case .headingLargeBold: return .system(size: 56, weight: .bold)
        case .headingLargeSemibold: return .system(size: 40, weight: .semibold)
        case .headingMediumBold: return .system(size: 20, weight: .bold)
        case .paragraphLargeRegular: return .system(size: 17, weight: .regular)
        case .paragraphRegular: return .system(size: 15, weight: .regular)
        case .paragraphBold: return .system(size: 15, weight: .bold)
        case .uiLargeBold: return .system(size: 17, weight: .semibold)
        case .uiLargeRegular: return .system(size: 17, weight: .regular)
        case .uiRegular: return .system(size: 13, weight: .regular)
        case .uiSmallSemibold: return .system(size: 13, weight: .semibold)
        }
    }
}

public extension View {
    func typography(_ type: FontType) -> some View {
        self.font(type.font)
    }
}
