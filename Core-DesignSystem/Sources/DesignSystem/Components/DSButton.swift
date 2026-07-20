import SwiftUI

public enum DSButtonType {
    case primary
    case secondary
    case tertiary
    /// Neutral pill for third-party sign-in buttons (e.g. Apple, Google) — background
    /// reuses `DSColor.Background.Button.disabled` (#F2F2F2, matches Figma's `surface/page`).
    case social
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

    var value: CGFloat {
        switch self {
        case .regular: return 52
        case .compact: return 36
        case .small: return 32
        case .social: return 48
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
                .background(backgroundColor)
                .clipShape(Circle())
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
                .background(backgroundColor)
                .clipShape(Capsule())
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
        case .social:
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
        case .textStyle:
            return .clear
        }
    }
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
    }
    .padding(24)
}
