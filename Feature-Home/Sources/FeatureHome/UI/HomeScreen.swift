import DesignSystem
import SwiftUI

/// Stand-in for the real Home tab until that screen exists. Owns its own Log Out
/// loading state so it resets whenever the authenticated root remounts after a re-login.
struct HomeScreen: View {
    let onLogOut: () -> Void
    @State private var isLoggingOut = false

    var body: some View {
        VStack(spacing: DSConstant.large.value) {
            Spacer()
            VStack(spacing: DSConstant.medium.value) {
                Text("Home")
                    .typography(.headingMediumBold)
                    .foregroundColor(DSColor.Text.heading)
                Text("This screen is under construction. Check back soon!")
                    .typography(.paragraphRegular)
                    .foregroundColor(DSColor.Text.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
            DSButton(title: "Log Out", type: .primary, isLoading: isLoggingOut) {
                isLoggingOut = true
                onLogOut()
            }
        }
        .padding(DSConstant.xxLarge.value)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DSColor.Background.Layer.level0.ignoresSafeArea())
    }
}
