import SwiftUI

public extension View {
    func defaultSidePadding() -> some View {
        padding(.horizontal, DSConstant.large.value)
    }

    func defaultCornerRadius() -> some View {
        cornerRadius(DSConstant.large.value)
    }

    /// Soft, mostly-downward shadow shared by card-style surfaces floating on the
    /// onboarding gradient (`DSStatusCard`, `LoyaltyCard`) — subtle since it often
    /// sits directly on a colored background rather than plain white.
    func dsCardShadow() -> some View {
        shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
    }
}
