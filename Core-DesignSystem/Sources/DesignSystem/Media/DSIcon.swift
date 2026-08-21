import SwiftUI

/// Single source of truth for every icon used in the app — both bundled
/// vector assets and SF Symbols. Callers never reach for `Image(systemName:)`
/// or `Image(_:bundle:)` directly; they add a case here instead.
public enum DSIcon {
    case appleLogo
    case google
    case storefront
    case info
    case externalLink
    case pencil
    case next
    case warningTriangle
    /// Password field "show" toggle (`DSInputField`'s `.password` variant).
    case eye
    /// Password field "hide" toggle (`DSInputField`'s `.password` variant).
    case eyeSlash
    /// Trailing accessory for `DSInputField`'s `.date` variant.
    case calendar
    /// Checked-state glyph for `DSCheckbox`, `DSSelectionControlStyle`, and
    /// `DSSelectableRowGroup`'s selected row. (Asset filename keeps the designer's
    /// spelling, "minitCheckmark".)
    case checkmark
    /// White circle-with-checkmark glyph (`PasswordChangedScreen` success state).
    case minitCheckbox
    /// System chevron — prefer `miniArrowLeft` for branded back affordances.
    case chevronLeft
    /// Branded left-arrow glyph for circular back buttons (onboarding gradient + scanner).
    /// Asset name keeps the designer's spelling (`miniArrowLeft`).
    case miniArrowLeft
    /// Rank badge glyph on the onboarding loyalty-card preview.
    case minitArmor
    /// Grid/QR-style glyph for the onboarding loyalty-card preview's "Loyalty Card" chip.
    case minitQrCode
    /// Capture-button glyph on the onboarding QR scanner screen. (Asset filename keeps the
    /// designer's original spelling, "minitCamerIcon" — this case name uses the correct
    /// spelling.)
    case minitCamera
    /// 8-spoke spinner glyph driving `DSProgressView`'s continuous rotation. Not
    /// typically used directly via `DSIconView` — go through `DSProgressView` instead
    /// so the spin animation stays consistent everywhere loading state is shown.
    case miniLoader
    /// Tab bar Home selected. Tint via `DSIconView`.
    case homeSelected
    /// Tab bar Home unselected.
    case homeUnselected
    /// Tab bar Offers selected.
    case discountSelected
    /// Tab bar Offers unselected.
    case discountUnselected
    /// Tab bar Map selected.
    case mapSelected
    /// Tab bar Map unselected.
    case mapUnselected
    /// Tab bar Card selected.
    case cardSelected
    /// Tab bar Card unselected.
    case cardUnselected
    /// Tab bar Game selected.
    case gameSelected
    /// Tab bar Game unselected.
    case gameUnselected
    /// Notification bell for the Home header (white glyph on glass circle).
    case minitBell
    /// Pastry glyph for notification rows (e.g. "First scan of the day").
    case minitIcBaguette
    /// Pastry glyph for notification rows (e.g. "New product discovered").
    case minitIcBretzel
    /// Small orange coin prefix for "+N pts" labels on notification rows.
    case minitPointCoin
    /// Plain right-pointing shaft arrow (not a chevron) for `DSBannerCarousel`'s
    /// decorative circular CTA glyph. Asset filename keeps the designer's spelling
    /// ("minitArrowRight").
    case arrowRight
    /// Branded right chevron for circular "see all" affordances (`DSCircleItemList`).
    /// Asset filename keeps the designer's spelling ("minitChevronRight").
    case chevronRight
    /// QR-scan line glyph for `DSBadgeCardList`'s "use your loyalty card" challenge.
    /// Asset filename keeps the designer's spelling ("minitIcQrScanLine").
    case qrScanLine
    /// Croissant pastry glyph for `DSBadgeCardList`'s "pizza/bakery"-style challenges.
    /// Asset filename keeps the designer's spelling ("minitIcCroissant").
    case croissant
    /// Drinks line glyph for `DSBadgeCardList`'s "add a coffee" challenge. Asset
    /// filename keeps the designer's spelling ("minitIcDrinksLine").
    case coffeeCup

    public var image: Image {
        switch self {
        case .appleLogo: return Image("Icon/AppleLogo", bundle: .module)
        case .google: return Image("Icon/Google", bundle: .module)
        case .storefront: return Image(systemName: "storefront.fill")
        case .info: return Image(systemName: "info.circle.fill")
        case .externalLink: return Image(systemName: "arrow.up.forward")
        case .pencil: return Image(systemName: "pencil")
        case .next: return Image(systemName: "chevron.right")
        case .warningTriangle: return Image(systemName: "exclamationmark.triangle.fill")
        case .eye: return Image(systemName: "eye")
        case .eyeSlash: return Image(systemName: "eye.slash")
        case .calendar: return Image(systemName: "calendar")
        case .checkmark:
            return Image("Icon/minitCheckmark", bundle: .module).renderingMode(.template)
        case .minitCheckbox: return Image("Icon/minitCheckbox", bundle: .module)
        case .chevronLeft: return Image(systemName: "chevron.left")
        case .miniArrowLeft:
            return Image("Icon/miniArrowLeft", bundle: .module).renderingMode(.template)
        case .minitArmor: return Image("Icon/minitArmorIcon", bundle: .module)
        case .minitQrCode: return Image("Icon/minitQrCodeIcon", bundle: .module)
        case .minitCamera: return Image("Icon/minitCamerIcon", bundle: .module)
        case .miniLoader:
            return Image("Icon/miniLoader", bundle: .module).renderingMode(.template)
        case .homeSelected:
            return Image("Icon/minitTabHomeSelected", bundle: .module).renderingMode(.template)
        case .homeUnselected:
            return Image("Icon/minitTabHomeUnselected", bundle: .module).renderingMode(.template)
        case .discountSelected:
            return Image("Icon/minitTabDiscountSelected", bundle: .module).renderingMode(.template)
        case .discountUnselected:
            return Image("Icon/minitTabDiscountUnselected", bundle: .module).renderingMode(.template)
        case .mapSelected:
            return Image("Icon/minitTabMapSelected", bundle: .module).renderingMode(.template)
        case .mapUnselected:
            return Image("Icon/minitTabMapUnselected", bundle: .module).renderingMode(.template)
        case .cardSelected:
            return Image("Icon/minitTabCardSelected", bundle: .module).renderingMode(.template)
        case .cardUnselected:
            return Image("Icon/minitTabCardUnselected", bundle: .module).renderingMode(.template)
        case .gameSelected:
            return Image("Icon/minitTabGameSelected", bundle: .module).renderingMode(.template)
        case .gameUnselected:
            return Image("Icon/minitTabGameUnselected", bundle: .module).renderingMode(.template)
        case .minitBell:
            return Image("Icon/minitBell", bundle: .module).renderingMode(.template)
        case .minitIcBaguette:
            return Image("Icon/minitIcBaguette", bundle: .module).renderingMode(.template)
        case .minitIcBretzel:
            return Image("Icon/minitIcBretzel", bundle: .module).renderingMode(.template)
        case .minitPointCoin:
            return Image("Icon/minitPointCoin", bundle: .module)
        case .arrowRight:
            return Image("Icon/minitArrowRight", bundle: .module).renderingMode(.template)
        case .chevronRight:
            return Image("Icon/minitChevronRight", bundle: .module).renderingMode(.template)
        case .qrScanLine:
            return Image("Icon/minitIcQrScanLine", bundle: .module).renderingMode(.template)
        case .croissant:
            return Image("Icon/minitIcCroissant", bundle: .module).renderingMode(.template)
        case .coffeeCup:
            return Image("Icon/minitIcDrinksLine", bundle: .module).renderingMode(.template)
        }
    }
}

public struct DSIconView: View {
    let icon: DSIcon
    public var size: CGFloat
    public var renderingMode: Image.TemplateRenderingMode?
    public var color: Color

    public init(
        icon: DSIcon,
        size: CGFloat = 16,
        renderingMode: Image.TemplateRenderingMode? = .template,
        color: Color = DSColor.Icon.primary
    ) {
        self.icon = icon
        self.size = size
        self.renderingMode = renderingMode
        self.color = color
    }

    public var body: some View {
        icon.image
            .renderingMode(renderingMode)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundColor(color)
    }
}

#Preview {
    VStack(spacing: DSConstant.medium.value) {
        HStack(spacing: DSConstant.medium.value) {
            DSIconView(icon: .storefront)
            DSIconView(icon: .info)
            DSIconView(icon: .externalLink)
            DSIconView(icon: .pencil)
            DSIconView(icon: .next)
            DSIconView(icon: .warningTriangle)
            DSIconView(icon: .appleLogo, renderingMode: .original)
            DSIconView(icon: .google, renderingMode: .original)
        }
        HStack(spacing: DSConstant.medium.value) {
            DSIconView(icon: .eye)
            DSIconView(icon: .eyeSlash)
            DSIconView(icon: .calendar)
            DSIconView(icon: .checkmark)
            DSIconView(icon: .minitCheckbox, size: 24, renderingMode: .template)
        }
        HStack(spacing: DSConstant.medium.value) {
            DSIconView(icon: .chevronLeft)
            DSIconView(icon: .chevronRight)
            DSIconView(icon: .miniArrowLeft)
            DSIconView(icon: .minitArmor, renderingMode: .original)
            DSIconView(icon: .minitQrCode, renderingMode: .original)
            DSIconView(icon: .minitCamera, renderingMode: .original)
            DSIconView(icon: .miniLoader)
        }
        HStack(spacing: DSConstant.medium.value) {
            DSIconView(icon: .qrScanLine)
            DSIconView(icon: .croissant)
            DSIconView(icon: .coffeeCup)
        }
        HStack(spacing: DSConstant.medium.value) {
            DSIconView(icon: .homeSelected, size: 24, color: DSColor.Background.Button.secondary)
            DSIconView(icon: .discountUnselected, size: 24, color: DSColor.Icon.secondary)
            DSIconView(icon: .mapUnselected, size: 24, color: DSColor.Icon.secondary)
            DSIconView(icon: .cardUnselected, size: 24, color: DSColor.Icon.secondary)
            DSIconView(icon: .gameUnselected, size: 24, color: DSColor.Icon.secondary)
        }
    }
    .padding()
}
