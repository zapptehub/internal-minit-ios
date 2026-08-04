import CoreExtensions
import SwiftUI

/// Shared placeholder screen for tabs whose real feature hasn't landed yet (Offers, Map, Card,
/// Game) — only the feature-name headline differs per tab; the body copy and layout are
/// otherwise identical, so this is centralized here instead of copy-pasted into each tiny
/// feature module.
public struct UnderConstructionScreen: View {
    private let headlineKey: String
    @Environment(\.locale) private var locale

    /// `headlineKey` is a `Localizable.xcstrings` key resolved against this module's own
    /// `common.tabName.*` catalog entries — callers don't need their own localization setup.
    public init(headlineKey: String) {
        self.headlineKey = headlineKey
    }

    public var body: some View {
        VStack(spacing: DSConstant.medium.value) {
            Spacer()
            Text(DesignSystemLocalizedString.string(headlineKey, locale: locale))
                .typography(.headingMediumBold)
                .foregroundColor(DSColor.Text.heading)
            Text(DesignSystemLocalizedString.string("common.underConstructionScreen.message", locale: locale))
                .typography(.paragraphRegular)
                .foregroundColor(DSColor.Text.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(DSConstant.xxLarge.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }
}

#Preview("UnderConstructionScreen") {
    UnderConstructionScreen(headlineKey: "common.tabName.offers")
}
