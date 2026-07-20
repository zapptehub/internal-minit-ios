import SwiftUI
import DesignSystem

/// The one part of the auth flow's UI that's genuinely constant across every step — the Minit
/// logo. `LoginScreen` renders this once, above its `NavigationStack`, instead of
/// each individual screen re-rendering it as part of its own content. Everything else
/// (headline, subtitle, fields, buttons) changes per step and belongs to that step's own
/// screen. See `plans/ios-auth-flow-multi-step.md`.
struct AuthFlowNavigationBar: View {
    /// Figma spec (node `6161:2119`) — gap between the sheet's top edge and the logo.
    static let topPadding: CGFloat = 34

    var body: some View {
        DSImageView(image: .minitLogo, size: CGSize(width: 75, height: 75))
            .accessibilityHidden(true)
    }
}

#Preview("AuthFlowNavigationBar") {
    VStack(alignment: .leading) {
        AuthFlowNavigationBar()
        Spacer()
    }
    .padding(.top, AuthFlowNavigationBar.topPadding)
    .defaultSidePadding()
    .background(DSColor.Background.Layer.level0)
}
