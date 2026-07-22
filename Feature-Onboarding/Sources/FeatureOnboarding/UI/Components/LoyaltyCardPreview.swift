import SwiftUI
import DesignSystem

/// Static marketing preview shown above the loyalty-decision rows — "Rank Up" glyph +
/// title/subtitle, a placeholder points value, the decorative person illustration, and
/// a "Loyalty Card" chip. Per the Task 1.1 checklist, the points value ("1,410") is
/// static preview art, not bound to a real card (no card exists yet at this step).
///
/// Feature-local per the Task 2.1 mapping — highly bespoke/illustration-driven, no
/// design-system equivalent (`DSCard` doesn't accommodate the rank glyph, large points
/// number, or illustration).
struct LoyaltyCardPreview: View {
    private static let illustrationSize = CGSize(width: 84, height: 84)
    private static let rankGlyphSize: CGFloat = 20
    private static let chipGlyphSize: CGFloat = 14

    /// Static placeholder — see type doc comment.
    private let pointsValue = "1,410"

    var body: some View {
        VStack(alignment: .leading, spacing: DSConstant.medium.value) {
            HStack(alignment: .top, spacing: DSConstant.medium.value) {
                VStack(alignment: .leading, spacing: DSConstant.small.value) {
                    HStack(spacing: DSConstant.small.value) {
                        DSIconView(icon: .minitArmor, size: Self.rankGlyphSize, renderingMode: .original)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "onboarding.loyalty.preview.rankUp", bundle: .module))
                                .typography(.uiLargeBold)
                                .foregroundColor(DSColor.Text.heading)

                            Text(String(localized: "onboarding.loyalty.preview.benefits", bundle: .module))
                                .typography(.paragraphRegular)
                                .foregroundColor(DSColor.Text.secondary)
                        }
                    }

                    Text(pointsValue)
                        .typography(.headingMediumBold)
                        .foregroundColor(DSColor.Text.heading)
                        .padding(.top, DSConstant.xSmall.value)
                }

                Spacer(minLength: 0)

                DSImageView(image: .minitCashPerson, size: Self.illustrationSize)
                    .accessibilityHidden(true)
            }

            chip
        }
        .padding(DSConstant.mediumLarge.value)
        .background(DSColor.Background.Layer.level0)
        .cornerRadius(DSConstant.medium.value)
    }

    private var chip: some View {
        HStack(spacing: DSConstant.small.value) {
            DSIconView(icon: .minitQrCode, size: Self.chipGlyphSize, renderingMode: .original)
            Text(String(localized: "onboarding.loyalty.preview.chip", bundle: .module))
                .typography(.uiSmallSemibold)
                .foregroundColor(DSColor.Text.heading)
        }
        .padding(.horizontal, DSConstant.mediumLarge.value)
        .padding(.vertical, DSConstant.small.value)
        .background(DSColor.Background.Button.disabled)
        .clipShape(Capsule(style: .continuous))
    }
}

#Preview("LoyaltyCardPreview") {
    LoyaltyCardPreview()
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.Background.Button.primary)
}
