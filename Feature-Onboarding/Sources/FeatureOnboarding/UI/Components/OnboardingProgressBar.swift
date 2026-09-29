import SwiftUI
import DesignSystem

/// Continuous top progress track for the onboarding wizard — thin capsule fill over a
/// translucent white track, nearly full-bleed within the scaffold's horizontal margins.
struct OnboardingProgressBar: View {
    let progress: Double
    @Environment(\.locale) private var locale

    /// Figma track height is 3 (2097:850 and the other onboarding frames).
    /// Figma TOP fills the track with `rgba(255,255,255,0.25)`.
    static let height: CGFloat = 3
    static let trackOpacity: Double = 0.25

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(Self.trackOpacity))
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(Self.height, proxy.size.width * clamped))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(OnboardingLocalizedString.string("onboarding.a11y.progress", locale: locale))
        .accessibilityValue("\(Int((min(max(progress, 0), 1) * 100).rounded()))%")
    }
}

#Preview("OnboardingProgressBar") {
    VStack(alignment: .leading, spacing: 16) {
        OnboardingProgressBar(progress: 0.16)
        OnboardingProgressBar(progress: 0.33)
        OnboardingProgressBar(progress: 0.85)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(DSColor.Background.Button.primary)
}
