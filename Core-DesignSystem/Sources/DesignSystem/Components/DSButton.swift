import SwiftUI

public enum DSButtonType {
    case primary
    case secondary
    case tertiary
    /// Neutral pill for third-party sign-in buttons (e.g. Apple, Google) — background
    /// reuses `DSColor.Background.Button.disabled` (#F2F2F2, matches Figma's `surface/page`).
    case social
    /// Raised/embossed pill used by the onboarding loyalty card's "Loyalty Card" chip —
    /// a top-to-bottom `#F2F2F2` → `#FFFFFF` gradient, `#DFDFDF` 1pt border, and a soft
    /// drop shadow. Currently a one-off special case for that single call site; promote
    /// to real design tokens if a second call site needs this look.
    case loyaltyCard
    /// Frosted glass circle for icon-only affordances over photo/video content (e.g. the
    /// full-screen QR scanner's back button) — `.ultraThinMaterial` background, a hairline
    /// white border, and a white glyph. Forces `.colorScheme(.dark)` internally so the
    /// material always reads as "glass over dark content" regardless of the device's
    /// system appearance.
    case glass
    case textStyle(textColor: Color, typography: FontType)
}

public enum DSButtonHeightStyle {
    case regular
    case compact
    /// 32pt — smaller pill for secondary/inline actions (e.g. "Send Again"), paired with a
    /// smaller `uiRegular` label instead of `.regular`/`.compact`'s `uiLargeBold`.
    case small
    /// 48pt — matches Figma's spec for the Apple/Google sign-in pills, the loyalty card
    /// chip, and the scanner's glass back button.
    case large
    /// 64pt — matches Figma's spec for the scanner's decorative capture button.
    case xLarge

    var value: CGFloat {
        switch self {
        case .regular: return DSComponentMetric.Button.regularHeight
        case .compact: return DSComponentMetric.Button.compactHeight
        case .small: return DSComponentMetric.Button.smallHeight
        case .large: return DSComponentMetric.Button.largeHeight
        case .xLarge: return DSComponentMetric.Button.xLargeHeight
        }
    }
}

public enum DSButtonWidthStyle {
    case expanded
    case compact
    case icon
}

public struct DSButton: View {
    let title: String
    let type: DSButtonType
    let isEnabled: Bool
    let isLoading: Bool
    let icon: DSIcon?
    /// Explicit render size for `icon`, `widthStyle == .icon` only — when `nil`, the icon
    /// renders at its asset's native intrinsic size (existing behavior for every call site
    /// that predates this parameter, e.g. `OnboardingBackButton`'s 16×16 `miniArrowLeft`).
    let iconSize: CGFloat?
    let heightStyle: DSButtonHeightStyle
    let widthStyle: DSButtonWidthStyle
    /// VoiceOver label override — required for icon-only buttons where `title` is empty.
    let accessibilityLabelText: String?
    let action: () -> Void

    public init(
        title: String,
        type: DSButtonType,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: DSIcon? = nil,
        iconSize: CGFloat? = nil,
        heightStyle: DSButtonHeightStyle = .regular,
        widthStyle: DSButtonWidthStyle = .expanded,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.type = type
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.icon = icon
        self.iconSize = iconSize
        self.heightStyle = heightStyle
        self.widthStyle = widthStyle
        self.accessibilityLabelText = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        // `Material` tints itself by the current color scheme, not by whatever's
        // actually behind it — `.glass` is always used over dark photo/video content,
        // so force dark here rather than relying on every call site to remember to do it.
        if isGlass {
            buttonBody.environment(\.colorScheme, .dark)
        } else {
            buttonBody
        }
    }

    private var buttonBody: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            action()
        } label: {
            if widthStyle == .icon {
                Group {
                    if isLoading {
                        ProgressView().tint(labelColor)
                    } else if let icon, let iconSize {
                        DSIconView(icon: icon, size: iconSize, color: labelColor)
                    } else {
                        (icon?.image ?? Image(systemName: "circle"))
                            .foregroundColor(labelColor)
                    }
                }
                .frame(width: heightStyle.value, height: heightStyle.value)
                .background(backgroundView)
                .overlay(borderOverlay(Circle()))
                .clipShape(Circle())
                .shadow(
                    color: shadowColor,
                    radius: DSShadow.loyaltyButton.radius,
                    x: DSShadow.loyaltyButton.x,
                    y: DSShadow.loyaltyButton.y
                )
            } else {
                HStack(spacing: isLoyaltyCard ? LoyaltyCardMetrics.chipIconGap : DSConstant.small.value) {
                    if isLoading {
                        ProgressView().tint(labelColor)
                    } else if isLoyaltyCard {
                        // `.loyaltyCard` uses `paragraphBold`. Other types keep `uiLargeBold`
                        // and the intrinsic icon.
                        if let icon {
                            DSIconView(
                                icon: icon,
                                size: LoyaltyCardMetrics.chipIconSize,
                                renderingMode: .original
                            )
                        }
                        Text(title)
                            .typography(LoyaltyCardMetrics.chipLabelStyle)
                            .foregroundColor(labelColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    } else {
                        icon?.image
                            .foregroundColor(labelColor)
                        Text(title)
                            .typography(labelFont)
                            .foregroundColor(labelColor)
                    }
                }
                .padding(.horizontal, widthStyle == .compact ? DSConstant.medium.value : DSConstant.large.value)
                .frame(maxWidth: widthStyle == .expanded ? .infinity : nil)
                .frame(height: heightStyle.value)
                .background(backgroundView)
                .overlay(borderOverlay(Capsule()))
                .clipShape(Capsule())
                .shadow(
                    color: shadowColor,
                    radius: DSShadow.loyaltyButton.radius,
                    x: DSShadow.loyaltyButton.x,
                    y: DSShadow.loyaltyButton.y
                )
            }
        }
        .disabled(!isEnabled)
        .allowsHitTesting(isEnabled && !isLoading)
        .accessibilityLabel(resolvedAccessibilityLabel)
    }

    private var resolvedAccessibilityLabel: Text {
        if let accessibilityLabelText, !accessibilityLabelText.isEmpty {
            return Text(accessibilityLabelText)
        }
        return Text(title)
    }

    private var labelFont: FontType {
        if case .textStyle(_, let t) = type { return t }
        return heightStyle == .small ? .uiRegular : .uiLargeBold
    }

    private var labelColor: Color {
        switch type {
        case .primary, .secondary, .tertiary:
            return isEnabled ? DSColor.Text.onColorButton : DSColor.Text.disabled
        case .social, .loyaltyCard:
            return isEnabled ? DSColor.Text.primary : DSColor.Text.disabled
        case .glass:
            return isEnabled ? .white : .white.opacity(0.5)
        case .textStyle(let color, _):
            return color
        }
    }

    private var backgroundColor: Color {
        switch type {
        case .primary:
            return isEnabled ? DSColor.Background.Button.primary : DSColor.Background.Button.disabled
        case .secondary:
            return isEnabled ? DSColor.Background.Button.secondary : DSColor.Background.Button.disabled
        case .tertiary:
            return isEnabled ? DSColor.Background.Button.tertiary : DSColor.Background.Button.disabled
        case .social:
            return DSColor.Background.Button.disabled
        case .loyaltyCard:
            // Unused — `.loyaltyCard` renders its gradient via `backgroundView` instead.
            return .clear
        case .glass:
            // Unused — `.glass` renders `.ultraThinMaterial` via `backgroundView` instead.
            return .clear
        case .textStyle:
            return .clear
        }
    }

    /// `.loyaltyCard` renders a top-to-bottom gradient and `.glass` renders a frosted
    /// material rather than a flat color; every other type falls back to `backgroundColor`.
    @ViewBuilder
    private var backgroundView: some View {
        switch type {
        case .loyaltyCard:
            LinearGradient(
                colors: [Self.loyaltyCardGradientTop, Self.loyaltyCardGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        case .glass:
            Rectangle().fill(.ultraThinMaterial)
        default:
            backgroundColor
        }
    }

    /// `.loyaltyCard` gets a hairline `#DFDFDF` border matching its clip shape, `.glass`
    /// gets a hairline translucent white border; every other type has no border.
    @ViewBuilder
    private func borderOverlay<S: Shape>(_ shape: S) -> some View {
        if isLoyaltyCard {
            shape.stroke(Self.loyaltyCardBorder, lineWidth: DSBorderWidth.hairline)
        } else if isGlass {
            shape.stroke(Self.glassBorder, lineWidth: DSBorderWidth.hairline)
        }
    }

    private var shadowColor: Color {
        isLoyaltyCard ? DSShadow.loyaltyButton.color : .clear
    }

    private var isLoyaltyCard: Bool {
        if case .loyaltyCard = type { return true }
        return false
    }

    private var isGlass: Bool {
        if case .glass = type { return true }
        return false
    }

    // MARK: - `.loyaltyCard` constants

    private static let loyaltyCardGradientTop = DSColor.Background.Layer.level1
    private static let loyaltyCardGradientBottom = DSColor.Background.Layer.level0
    private static let loyaltyCardBorder = DSPlatformColorExtension.loyaltyButtonBorder.color

    // MARK: - `.glass` constants

    private static let glassBorder = Color.white.opacity(0.25)
}

#Preview {
    VStack(spacing: DSConstant.medium.value) {
        DSButton(title: "Redeem Rewards", type: .primary) { }
        DSButton(title: "Redeem Rewards", type: .secondary) { }
        DSButton(title: "Reset Password", type: .tertiary) { }
        DSButton(title: "Redeem Rewards", type: .primary, isEnabled: false) { }

        // Loading state — label content swaps for a tinted ProgressView; taps are ignored.
        DSButton(title: "Redeem Rewards", type: .primary, isLoading: true) { }
        DSButton(title: "Redeem Rewards", type: .secondary, isLoading: true) { }

        HStack(spacing: DSConstant.medium.value) {
            DSButton(title: "", type: .primary, icon: .storefront, widthStyle: .icon) { }
            DSButton(title: "", type: .secondary, icon: .storefront, widthStyle: .icon) { }
            DSButton(title: "", type: .tertiary, icon: .storefront, widthStyle: .icon) { }
            DSButton(title: "", type: .primary, isEnabled: false, icon: .storefront, widthStyle: .icon) { }
            DSButton(title: "", type: .primary, isLoading: true, widthStyle: .icon) { }
        }

        // Social sign-in pills — icon + text, expanded width, .social type/height.
        HStack(spacing: DSConstant.medium.value) {
            DSButton(title: "Apple", type: .social, icon: .appleLogo, heightStyle: .large) { }
            DSButton(title: "Google", type: .social, icon: .google, heightStyle: .large) { }
        }

        // Small pill — smaller height + label, for inline secondary actions (e.g. "Send Again").
        HStack(spacing: DSConstant.medium.value) {
            DSButton(title: "Send Again", type: .tertiary, heightStyle: .small, widthStyle: .compact) { }
            DSButton(title: "Send Again", type: .tertiary, isEnabled: false, heightStyle: .small, widthStyle: .compact) { }
        }

        // Loyalty card chip — raised gradient pill, expanded width, .loyaltyCard type/height.
        DSButton(title: "Loyalty Card", type: .loyaltyCard, icon: .minitQrCode, heightStyle: .large) { }

        // Glass back button — frosted material circle over dark content, e.g. the scanner.
        DSButton(title: "", type: .glass, icon: .miniArrowLeft, iconSize: 20, heightStyle: .large, widthStyle: .icon) { }
            .padding(24)
            .background(Color.black)

        // Scanner capture button — decorative-only, oversized icon-only circle.
        DSButton(title: "", type: .primary, icon: .minitCamera, iconSize: 24, heightStyle: .xLarge, widthStyle: .icon) { }
    }
    .padding(24)
    .background(Color(white: 0.95))
}
