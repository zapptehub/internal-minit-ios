import SwiftUI

public extension View {
    func defaultSidePadding() -> some View {
        padding(.horizontal, DSMetric.Spacing.large)
    }

    /// Soft, mostly-downward shadow shared by card-style surfaces floating on the
    /// onboarding gradient (`DSStatusCard`, `LoyaltyCard`) — subtle since it often
    /// sits directly on a colored background rather than plain white.
    func dsCardShadow() -> some View {
        dsShadow(DSShadow.card)
    }
}
