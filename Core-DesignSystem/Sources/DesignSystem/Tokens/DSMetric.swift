import SwiftUI

/// Reusable dimensions that resolve to the Mode 1 numeric scale where possible.
internal enum DSMetric {
    enum Spacing {
        static let zero = DSPrimitiveScale.step0.value
        static let xxSmall = DSPrimitiveScale.step50.value
        static let xSmall = DSPrimitiveScale.step100.value
        static let small = DSPrimitiveScale.step200.value
        static let medium = DSPrimitiveScale.step300.value
        static let mediumLarge = DSPrimitiveScale.step400.value
        static let large = DSPrimitiveScale.step600.value
        static let xLarge = DSPrimitiveScale.step800.value
        static let xxLarge = DSPrimitiveScale.step1000.value
    }

    enum Size {
        static let iconExtraSmall = DSPrimitiveScale.step300.value
        static let iconSmall = DSPrimitiveScale.step400.value
        static let iconMedium = DSPrimitiveScale.step500.value
        static let iconLarge = DSPrimitiveScale.step600.value
        static let iconExtraLarge = DSPrimitiveScale.step800.value
        static let minimumTouchTarget = DSPrimitiveScale.step1200.value
    }
}

/// Product measurements that have no corresponding semantic value in the Mode 1 export.
internal enum DSPlatformMetric {
    enum Spacing {
        static let smallMedium: CGFloat = 6
    }

    enum Size {
        static let contentMaxWidth: CGFloat = 600
    }
}

/// Radius roles retained from the established product control hierarchy.
internal enum DSRadius {
    static let extraSmall = DSPrimitiveScale.step100.value
    static let small = DSPrimitiveScale.step200.value
    static let control = DSPrimitiveScale.step300.value
    static let media = DSPrimitiveScale.step400.value
    static let card = DSPrimitiveScale.step500.value
}

/// Stroke widths retained as platform component specifications.
internal enum DSBorderWidth {
    static let hairline: CGFloat = 1
    static let standard: CGFloat = 2
    static let selectableIndicator: CGFloat = 1.5
}

internal struct DSShadowToken {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

/// A Figma effect style made of two drop shadows, drawn under the component's own shape:
/// `far` first, then `near` on top. SwiftUI's shadow radius is half the Figma/CSS blur.
/// SwiftUI shadows have no spread, so the far shadow is cast by the shape inset by
/// `farCasterInset` on every side (corner radius reduced by the same amount), which is
/// what a negative CSS spread does.
internal struct DSLayeredShadowToken {
    let near: DSShadowToken
    let far: DSShadowToken
    /// How far the far shadow's caster is inset from the shape: the Figma spread, negated.
    let farCasterInset: CGFloat
}

/// Shadow roles remain iOS-specific because the design export has no shadow tokens.
internal enum DSShadow {
    static let card = DSShadowToken(
        color: .black.opacity(0.12),
        radius: DSRadius.media,
        x: 0,
        y: DSMetric.Spacing.small
    )
    static let pinnedSheet = DSShadowToken(
        color: .black.opacity(0.1),
        radius: DSPrimitiveScale.step200.value,
        x: 0,
        y: -DSPrimitiveScale.step50.value
    )
    static let loyaltyButton = DSShadowToken(
        color: .black.opacity(0.08),
        radius: DSPrimitiveScale.step50.value,
        x: 0,
        y: 1
    )
    /// `#3E3445`, the color of both Figma "Small" shadows.
    static let smallColor = Color(red: 0x3E / 255, green: 0x34 / 255, blue: 0x45 / 255)
    /// Figma effect style "Small": the Challenge cards (6143:1889) and every Daily Offer
    /// banner (Home 6065:4747, Notifications 6123:1697).
    /// - near, `color/shadow/opacity-4` (`#3E34450A`): x 0, y 2, blur 4, spread 0.
    /// - far, `color/shadow/opacity-10` (`#3E34451A`): x 0, y 16, blur 32, spread −4.
    static let small = DSLayeredShadowToken(
        near: DSShadowToken(color: smallColor.opacity(10.0 / 255), radius: 4 / 2, x: 0, y: 2),
        far: DSShadowToken(color: smallColor.opacity(26.0 / 255), radius: 32 / 2, x: 0, y: 16),
        farCasterInset: 4
    )
}

/// Component-facing dimensions shared by existing Design System controls.
internal enum DSComponentMetric {
    enum Button {
        static let regularHeight = DSPrimitiveScale.step1400.value
        static let compactHeight = DSPrimitiveScale.step900.value
        static let smallHeight = DSPrimitiveScale.step800.value
        static let largeHeight = DSPrimitiveScale.step1200.value
        static let xLargeHeight = DSPrimitiveScale.step1600.value
    }

    enum Input {
        static let fieldHeight = DSPrimitiveScale.step1200.value
        static let numberCircleDiameter = DSPrimitiveScale.step1100.value
        static let textareaHeight: CGFloat = 120
    }

    enum SelectionControl {
        static let controlSize = DSMetric.Size.iconMedium
        static let checkmarkSize = DSMetric.Spacing.medium
    }

    enum SelectableRow {
        static let height = DSPrimitiveScale.step1400.value
    }

    enum Progress {
        static let diameter = DSPrimitiveScale.step1200.value
        static let iconSize = DSMetric.Size.iconLarge
    }

    enum PinnedSheet {
        static let handleWidth = DSPrimitiveScale.step900.value
        static let handleHeight: CGFloat = 5
        static let handleTopPadding: CGFloat = 5
    }
}

internal extension View {
    func dsShadow(_ token: DSShadowToken) -> some View {
        shadow(color: token.color, radius: token.radius, x: token.x, y: token.y)
    }
}
