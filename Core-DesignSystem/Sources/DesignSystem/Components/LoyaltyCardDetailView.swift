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
    private static let cardHeight: CGFloat = 402
    private static let cornerRadius: CGFloat = DSConstant.cardCornerRadius.value
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
        VStack(spacing: DSConstant.large.value) {
            Text(title ?? DesignSystemLocalizedString.string("common.loyaltyCardDetail.title", locale: locale))
                .typography(.headingLargeSemibold)
                .foregroundColor(DSColor.Text.heading)

            DSImageView(
                image: .mockQrCode,
                size: CGSize(width: Self.qrCodeSize, height: Self.qrCodeSize)
            )

            // Flat #F2F2F2 pill — `.social` is the only `DSButtonType` that renders a
            // plain neutral background regardless of state (see `DSButton`'s
            // `backgroundColor`), so it's reused here instead of a hardcoded literal.
            DSButton(
                title: closeLabel ?? DesignSystemLocalizedString.string("common.loyaltyCardDetail.close", locale: locale),
                type: .social,
                heightStyle: .large
            ) {
                onClose()
            }
        }
        .padding(DSConstant.large.value)
        .frame(maxWidth: .infinity, minHeight: Self.cardHeight, maxHeight: Self.cardHeight)
        .background(DSColor.Background.Layer.level0)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .dsCardShadow()
    }
}

/// Centered popup overlay (dimmed backdrop + tap-outside-to-dismiss) for presenting a
/// `LoyaltyCardDetailView`-style card, instead of a bottom sheet. Apply as the last
/// modifier on the screen's root view so the overlay draws above all of its content.
public struct DSPopupOverlay<PopupContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let horizontalPadding: CGFloat
    let popupContent: () -> PopupContent

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
        content.overlay {
            if isPresented {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture { isPresented = false }

                    popupContent()
                        .padding(.horizontal, horizontalPadding)
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: isPresented)
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
