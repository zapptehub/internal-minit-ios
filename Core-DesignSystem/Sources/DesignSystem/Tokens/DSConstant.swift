import CoreFoundation

/// Backward-compatible access to the Design System spacing and card-radius roles.
public enum DSConstant: Int {
    case xSmall = 4
    case smallMedium = 6
    case small = 8
    case medium = 12
    case mediumLarge = 16
    case large = 24
    case xLarge = 32
    case xxLarge = 40
    case cardCornerRadius = 20

    public var value: CGFloat {
        switch self {
        case .xSmall: return DSMetric.Spacing.xSmall
        case .smallMedium: return DSPlatformMetric.Spacing.smallMedium
        case .small: return DSMetric.Spacing.small
        case .medium: return DSMetric.Spacing.medium
        case .mediumLarge: return DSMetric.Spacing.mediumLarge
        case .large: return DSMetric.Spacing.large
        case .xLarge: return DSMetric.Spacing.xLarge
        case .xxLarge: return DSMetric.Spacing.xxLarge
        case .cardCornerRadius: return DSRadius.card
        }
    }
}
