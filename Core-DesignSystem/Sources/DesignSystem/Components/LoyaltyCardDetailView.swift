import CoreExtensions
import SwiftUI

/// Full loyalty-card QR detail card, presented from `LoyaltyCard`'s chip tap as a
/// centered popup (not a bottom sheet) — see `DSPopupOverlay`. QR artwork is mocked
/// (`mockQrCode`) until a real per-user code is wired up; the close action is a plain
/// dismiss until a real wallet-pass integration lands.
public struct LoyaltyCardDetailView: View {
    /// `nil` falls back to the localized `common.loyaltyCardDetail.*` strings, resolved
    /// against `\.locale` at render time — defaults can't be localized in `init`.
    let title: String?
    let closeLabel: String?
    let onClose: () -> Void

    @Environment(\.locale) private var locale

    /// Figma spec — fixed card height regardless of content, unlike `LoyaltyCard`'s
    /// content-driven `minHeight`.
    static let cardHeight: CGFloat = 402
    /// Figma "AMP / My Card" card (6078:4896): radius 27, continuous. Card-local; the
    /// shared `DSRadius.card` / `DSConstant.cardCornerRadius` stays 20. The clip and the
    /// card shadow follow this shape.
    static let cornerRadius: CGFloat = 27
    /// Figma 6078:4896 padding: top 40, sides 24, bottom 24.
    static let contentPaddingTop: CGFloat = DSConstant.xxLarge.value
    static let contentPaddingHorizontal: CGFloat = DSConstant.large.value
    static let contentPaddingBottom: CGFloat = DSConstant.large.value
    /// Figma gap 32 between title, QR code and button.
    static let contentSpacing: CGFloat = DSConstant.xLarge.value
    /// Figma effect "Extra Large".
    static let shadow = DSShadow.extraLarge
    /// Figma title 6078:5066: Sharp Grotesk SmBold 32, tracking −1, `#331A00`
    /// (`DSColor.Text.heading`), trimmed to cap height and baseline.
    static let titleStyle = FontType.headingPopupTitle
    /// Figma button label 6078:5103, Body/Bold/md: system bold 16, line height 20,
    /// `#1A1A1A` (`.social`'s `DSColor.Text.primary`). Popup-only; other buttons
    /// keep `uiLargeBold`.
    static let closeLabelStyle = FontType.bodyBoldMedium
    /// Figma button 6078:5101 is 56 tall (the Button component's Size=Large), which is
    /// `DSButton`'s `.regular`; `.large` is the 48 used by the loyalty chip and sign-in pills.
    static let closeButtonHeightStyle = DSButtonHeightStyle.regular
    private static let qrCodeSize: CGFloat = 195

    public init(
        title: String? = nil,
        closeLabel: String? = nil,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.closeLabel = closeLabel
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: Self.contentSpacing) {
            // Cap-to-baseline box like Figma's text-box trim; the stack's gap follows.
            SharpGroteskCapTrim(followingGap: Self.contentSpacing) {
                Text(title ?? DesignSystemLocalizedString.string("common.loyaltyCardDetail.title", locale: locale))
                    .typography(Self.titleStyle)
                    .foregroundColor(DSColor.Text.heading)
                    .accessibilityAddTraits(.isHeader)
            }

            // Android's QR is decorative (`DsImageView` contentDescription defaults to null).
            // The asset name is what VoiceOver would speak, so iOS names it instead.
            DSImageView(
                image: .mockQrCode,
                size: CGSize(width: Self.qrCodeSize, height: Self.qrCodeSize)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(DesignSystemA11y.text("common.a11y.loyaltyCardQrCode", locale: locale))
            .accessibilityAddTraits(.isImage)

            // Flat #F2F2F2 pill — `.social` is the only `DSButtonType` that renders a
            // plain neutral background regardless of state (see `DSButton`'s
            // `backgroundColor`), so it's reused here instead of a hardcoded literal.
            DSButton(
                title: closeLabel ?? DesignSystemLocalizedString.string("common.loyaltyCardDetail.close", locale: locale),
                type: .social,
                heightStyle: Self.closeButtonHeightStyle,
                labelStyle: Self.closeLabelStyle
            ) {
                onClose()
            }
        }
        .padding(.top, Self.contentPaddingTop)
        .padding(.horizontal, Self.contentPaddingHorizontal)
        .padding(.bottom, Self.contentPaddingBottom)
        // At least Figma's 402, content top-aligned: 40 + 23 + 32 + 195 + 32 + 56 + 24 = 402
        // exactly, so nothing is left over under the button. Taller content
        // (larger Dynamic Type) grows the card instead of being clipped.
        .frame(maxWidth: .infinity, minHeight: Self.cardHeight, alignment: .top)
        .background(DSColor.Background.Layer.level0)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .background(Self.shadowCasters)
    }

    /// Card-shaped layers behind the card that cast Figma's "Extra Large" shadows. They
    /// are hidden by the card, so only the shadows show. Popup-only; `dsCardShadow` is
    /// unchanged.
    private static var shadowCasters: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius - shadow.farCasterInset, style: .continuous)
                .fill(DSColor.Background.Layer.level0)
                .padding(shadow.farCasterInset)
                .dsShadow(shadow.far)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(DSColor.Background.Layer.level0)
                .dsShadow(shadow.near)
        }
        .accessibilityHidden(true)
    }
}

/// `DSPopupOverlay` values. Kept outside the generic modifier, which can't hold static
/// stored properties.
enum DSPopupMetrics {
    /// Figma "AMP / My Card" OVERLAY (6078:4893): black at 32% (was 0.4).
    static let scrimOpacity: Double = 0.32
}

/// Centered popup overlay (dimmed backdrop + tap-outside-to-dismiss) for presenting a
/// `LoyaltyCardDetailView`-style card, instead of a bottom sheet.
///
/// Under a `.dsPopupHost()` (the app's tab root) the popup is handed to the host and drawn
/// above the tab bar, centred on the full screen. Without a host it falls back to an
/// overlay on this view that still ignores safe areas, so it centres on the view's full
/// bounds; apply it as the last modifier on the screen's root view.
public struct DSPopupOverlay<PopupContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let horizontalPadding: CGFloat
    let popupContent: () -> PopupContent

    @Environment(\.dsPopupHost) private var host
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ownerID = UUID()

    public init(
        isPresented: Binding<Bool>,
        horizontalPadding: CGFloat = 20,
        @ViewBuilder popupContent: @escaping () -> PopupContent
    ) {
        self._isPresented = isPresented
        self.horizontalPadding = horizontalPadding
        self.popupContent = popupContent
    }

    public func body(content: Content) -> some View {
        if let host {
            content
                .onAppear { sync(host) }
                .onChange(of: isPresented) { sync(host) }
                .onChange(of: isEnabled) { sync(host) }
                .onDisappear { host.clear(ownerID: ownerID, reduceMotion: reduceMotion) }
        } else {
            content
                .accessibilityHidden(isPresented)
                .overlay {
                    DSPopupLayer(
                        isPresented: isPresented,
                        horizontalPadding: horizontalPadding,
                        onDismiss: { isPresented = false },
                        popupContent: popupContent
                    )
                }
        }
    }

    private func sync(_ host: DSPopupHostModel) {
        if isPresented {
            let binding = $isPresented
            host.present(
                AnyView(popupContent()),
                horizontalPadding: horizontalPadding,
                isEnabled: isEnabled,
                ownerID: ownerID,
                reduceMotion: reduceMotion,
                onDismiss: { binding.wrappedValue = false }
            )
        } else {
            host.clear(ownerID: ownerID, reduceMotion: reduceMotion)
        }
    }
}

public extension View {
    /// Presents `popupContent` as a centered, dimmed-backdrop popup (tap outside to
    /// dismiss) rather than a system sheet — matches the Figma "My loyalty card" mock.
    func dsPopup<PopupContent: View>(
        isPresented: Binding<Bool>,
        horizontalPadding: CGFloat = 20,
        @ViewBuilder popupContent: @escaping () -> PopupContent
    ) -> some View {
        modifier(
            DSPopupOverlay(
                isPresented: isPresented,
                horizontalPadding: horizontalPadding,
                popupContent: popupContent
            )
        )
    }
}

#Preview("LoyaltyCardDetailView") {
    LoyaltyCardDetailView(onClose: {})
        .padding(.horizontal, 20)
}
