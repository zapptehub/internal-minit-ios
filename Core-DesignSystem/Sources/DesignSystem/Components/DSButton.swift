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
    case textStyle(textColor: Color, typography: FontType)
}

public enum DSButtonHeightStyle {
    case regular
    case compact
    /// 32pt — smaller pill for secondary/inline actions (e.g. "Send Again"), paired with a
    /// smaller `uiRegular` label instead of `.regular`/`.compact`'s `uiLargeBold`.
    case small
    /// 48pt — matches Figma's spec for the Apple/Google sign-in pills.
    case social
    /// 48pt — matches Figma's spec for the loyalty card chip. Same numeric value as
    /// `.social`, named separately so each call site reads clearly on its own.
    case loyaltyCard

    var value: CGFloat {
        switch self {
        case .regular: return 52
        case .compact: return 36
        case .small: return 32
        case .social: return 48
        case .loyaltyCard: return 48
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
    let heightStyle: DSButtonHeightStyle
    let widthStyle: DSButtonWidthStyle
    let action: () -> Void

    public init(
        title: String,
        type: DSButtonType,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        icon: DSIcon? = nil,
        heightStyle: DSButtonHeightStyle = .regular,
        widthStyle: DSButtonWidthStyle = .expanded,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.type = type
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.icon = icon
        self.heightStyle = heightStyle
        self.widthStyle = widthStyle
        self.action = action
    }

    public var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            action()
        } label: {
            if widthStyle == .icon {
                Group {
                    if isLoading {
                        ProgressView().tint(labelColor)
                    } else {
                        (icon?.image ?? Image(systemName: "circle"))
                            .foregroundColor(labelColor)
                    }
                }
                .frame(width: heightStyle.value, height: heightStyle.value)
                .background(backgroundView)
                .overlay(borderOverlay(Circle()))
                .clipShape(Circle())
                .shadow(color: shadowColor, radius: Self.shadowRadius, x: 0, y: Self.shadowYOffset)
            } else {
                HStack(spacing: DSConstant.small.value) {
                    if isLoading {
                        ProgressView().tint(labelColor)
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
                .shadow(color: shadowColor, radius: Self.shadowRadius, x: 0, y: Self.shadowYOffset)
            }
        }
        .disabled(!isEnabled)
        .allowsHitTesting(isEnabled && !isLoading)
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
        case .textStyle:
            return .clear
        }
    }

    /// `.loyaltyCard` renders a top-to-bottom gradient rather than a flat color;
    /// every other type falls back to the plain `backgroundColor`.
    @ViewBuilder
    private var backgroundView: some View {
        switch type {
        case .loyaltyCard:
            LinearGradient(
                colors: [Self.loyaltyCardGradientTop, Self.loyaltyCardGradientBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        default:
            backgroundColor
        }
    }

    /// `.loyaltyCard` gets a hairline `#DFDFDF` border matching its clip shape; every
    /// other type has no border.
    @ViewBuilder
    private func borderOverlay<S: Shape>(_ shape: S) -> some View {
        if isLoyaltyCard {
            shape.stroke(Self.loyaltyCardBorder, lineWidth: 1)
        }
    }

    private var shadowColor: Color {
        isLoyaltyCard ? Self.loyaltyCardShadow : .clear
    }

    private var isLoyaltyCard: Bool {
        if case .loyaltyCard = type { return true }
        return false
    }

    // MARK: - `.loyaltyCard` constants

    private static let loyaltyCardGradientTop = Color(red: 0.949, green: 0.949, blue: 0.949) // #F2F2F2
    private static let loyaltyCardGradientBottom = Color.white // #FFFFFF
    private static let loyaltyCardBorder = Color(red: 0.875, green: 0.875, blue: 0.875) // #DFDFDF
    private static let loyaltyCardShadow = Color.black.opacity(0.08)
    private static let shadowRadius: CGFloat = 2
    private static let shadowYOffset: CGFloat = 1
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
            DSButton(title: "Apple", type: .social, icon: .appleLogo, heightStyle: .social) { }
            DSButton(title: "Google", type: .social, icon: .google, heightStyle: .social) { }
        }

        // Small pill — smaller height + label, for inline secondary actions (e.g. "Send Again").
        HStack(spacing: DSConstant.medium.value) {
            DSButton(title: "Send Again", type: .tertiary, heightStyle: .small, widthStyle: .compact) { }
            DSButton(title: "Send Again", type: .tertiary, isEnabled: false, heightStyle: .small, widthStyle: .compact) { }
        }

        // Loyalty card chip — raised gradient pill, expanded width, .loyaltyCard type/height.
        DSButton(title: "Loyalty Card", type: .loyaltyCard, icon: .minitQrCode, heightStyle: .loyaltyCard) { }
    }
    .padding(24)
    .background(Color(white: 0.95))
}
