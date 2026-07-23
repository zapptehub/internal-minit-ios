import SwiftUI
import DesignSystem

/// Static marketing preset of `LoyaltyCard`, shown above the loyalty-decision rows.
/// Per the Task 1.1 checklist, every value here is static preview art, not bound to a
/// real card (no card exists yet at this onboarding step).
///
/// Renders a "card stack" illusion — a second, scaled-down + blurred copy of the same
/// card sits behind and slightly below the real one, so only a soft sliver peeks out
/// past its bottom edge, matching the Figma reference.
struct LoyaltyCardPreview: View {
    private static let backCardScale: CGFloat = 0.92
    private static let backCardOffsetY: CGFloat = 38
    private static let backCardBlurRadius: CGFloat = 6
    private static let backCardOpacity: Double = 0.7

    var body: some View {
        ZStack {
            card
                .scaleEffect(Self.backCardScale)
                .offset(y: Self.backCardOffsetY)
                .blur(radius: Self.backCardBlurRadius)
                .opacity(Self.backCardOpacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            card
        }
    }

    private var card: some View {
        LoyaltyCard(
            rankTitle: String(localized: "onboarding.loyalty.preview.rankUp", bundle: .module),
            rankSubtitle: String(localized: "onboarding.loyalty.preview.benefits", bundle: .module),
            points: 1410,
            chipLabel: String(localized: "onboarding.loyalty.preview.chip", bundle: .module)
        )
    }
}

#Preview("LoyaltyCardPreview") {
    LoyaltyCardPreview()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.Background.Button.primary)
}
