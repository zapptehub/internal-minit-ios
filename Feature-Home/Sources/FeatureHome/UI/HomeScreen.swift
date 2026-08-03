import DataProfile
import DesignSystem
import SwiftUI

/// Home tab chrome. Owns Log Out confirmation so loading/alert state resets whenever
/// the authenticated root remounts after a re-login.
struct HomeScreen: View {
    let userId: String
    let profileRepository: ProfileRepository
    let onLogOut: () -> Void

    @State private var userName = ""
    @State private var showsLogOutConfirmation = false
    @State private var showsUnderConstructionAlert = false
    @State private var showsLoyaltyCardDetail = false
    @State private var isLoggingOut = false

    private static let headerButtonSize: CGFloat = 44
    private static let bellIconSize: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            greeting
                .padding(.top, DSConstant.mediumLarge.value)
            loyaltyCard
                .padding(.top, DSConstant.mediumLarge.value)
                .padding(.horizontal, DSConstant.mediumLarge.value)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LinearGradient.minitBackground.ignoresSafeArea())
        .task { await loadUserName() }
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
        .dsPopup(isPresented: $showsLoyaltyCardDetail) {
            LoyaltyCardDetailView {
                showsLoyaltyCardDetail = false
            }
        }
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

    /// Time-of-day prefix in inverse white; profile first name in heading brown.
    /// Pink name underline from the mock is deferred.
    private var greeting: some View {
        (
            Text("\(Self.timeOfDayGreeting) ")
                .foregroundColor(DSColor.Text.inverse)
            + Text(userName)
                .foregroundColor(DSColor.Text.heading)
        )
        .typography(.headingLargeSemibold)
        .padding(.horizontal, DSConstant.mediumLarge.value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(Self.timeOfDayGreeting) \(userName)".trimmingCharacters(in: .whitespaces))
    }

    /// Hardcoded Home mock values until live rank/points wiring lands.
    private var loyaltyCard: some View {
        LoyaltyCard(
            rankTitle: "Silver",
            rankSubtitle: "540 pts until Platinum",
            points: 3210,
            chipLabel: "Minit Card",
            showsShadow: false
        ) {
            showsLoyaltyCardDetail = true
        }
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

    private func loadUserName() async {
        do {
            let profile = try await profileRepository.fetchProfile(userId: userId)
            userName = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            userName = ""
        }
    }

    /// Matches the mock's "Good Morning" copy; switches for afternoon/evening locally.
    private static var timeOfDayGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
}

#Preview("HomeScreen") {
    HomeScreen(
        userId: "preview-user",
        profileRepository: PreviewHomeProfileRepository(name: "Iveta"),
        onLogOut: {}
    )
}

private struct PreviewHomeProfileRepository: ProfileRepository {
    let name: String

    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? {
        ProfileData(name: name, surname: "", email: "")
    }
}
