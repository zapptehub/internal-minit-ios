import SwiftUI
import DesignSystem

/// Continuous top progress track for the onboarding wizard — thin capsule fill over a
/// translucent white track, nearly full-bleed within the scaffold's horizontal margins.
struct OnboardingProgressBar: View {
    let progress: Double

    private static let height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.35))
                Capsule()
                    .fill(Color.white)
                    .frame(width: max(Self.height, proxy.size.width * clamped))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
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
