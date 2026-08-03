import DesignSystem
import SwiftUI

/// Home tab chrome. Owns Log Out confirmation so loading/alert state resets whenever
/// the authenticated root remounts after a re-login.
struct HomeScreen: View {
    let onLogOut: () -> Void

    @State private var showsLogOutConfirmation = false
    @State private var showsUnderConstructionAlert = false
    @State private var isLoggingOut = false

    private static let headerButtonSize: CGFloat = 40
    private static let bellIconSize: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient.minitBackground.ignoresSafeArea())
        .alert("Log Out", isPresented: $showsLogOutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Log Out", role: .destructive) {
                isLoggingOut = true
                onLogOut()
            }
        } message: {
            Text("You are logged in. Do you want to log out?")
        }
        .featureUnderConstructionAlert(isPresented: $showsUnderConstructionAlert)
        .disabled(isLoggingOut)
    }

    /// Leading profile + trailing bell, matching standard navigation-bar item placement.
    private var headerBar: some View {
        HStack {
            profileButton
            Spacer()
            bellButton
        }
        .padding(.horizontal, DSConstant.mediumLarge.value)
        .frame(height: 44)
    }

    private var profileButton: some View {
        Button {
            showsLogOutConfirmation = true
        } label: {
            DSImageView(
                image: .mockUserProfile,
                size: CGSize(width: Self.headerButtonSize, height: Self.headerButtonSize),
                contentMode: .fill
            )
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile")
    }

    @ViewBuilder
    private var bellButton: some View {
        if #available(iOS 26, *) {
            Button {
                showsUnderConstructionAlert = true
            } label: {
                DSIconView(
                    icon: .minitBell,
                    size: Self.bellIconSize,
                    color: .white
                )
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Notifications")
        } else {
            Button {
                showsUnderConstructionAlert = true
            } label: {
                DSIconView(
                    icon: .minitBell,
                    size: Self.bellIconSize,
                    color: .white
                )
                .frame(width: Self.headerButtonSize, height: Self.headerButtonSize)
                .background {
                    Circle().fill(.ultraThinMaterial)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
        }
    }
}

#Preview("HomeScreen") {
    HomeScreen(onLogOut: {})
}
