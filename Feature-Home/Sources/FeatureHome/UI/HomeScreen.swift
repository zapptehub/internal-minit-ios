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
    @State private var showsLoyaltyCardDetail = false
    @State private var showsNotifications = false
    @State private var isLoggingOut = false

    @Environment(\.locale) private var locale

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
            dailyOfferBanners
                .padding(.top, DSConstant.small.value)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(LinearGradient.minitBackground.ignoresSafeArea())
        .task { await loadUserName() }
        .alert(HomeLocalizedString.string("home.logOut.title", locale: locale), isPresented: $showsLogOutConfirmation) {
            Button(HomeLocalizedString.string("home.logOut.cancel", locale: locale), role: .cancel) {}
            Button(HomeLocalizedString.string("home.logOut.title", locale: locale), role: .destructive) {
                isLoggingOut = true
                onLogOut()
            }
        } message: {
            Text(HomeLocalizedString.string("home.logOut.message", locale: locale))
        }
        .dsPopup(isPresented: $showsLoyaltyCardDetail) {
            LoyaltyCardDetailView {
                showsLoyaltyCardDetail = false
            }
        }
        .fullScreenCover(isPresented: $showsNotifications) {
            NotificationsScreen {
                showsNotifications = false
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
        let timeOfDayGreeting = timeOfDayGreeting
        return (
            Text("\(timeOfDayGreeting) ")
                .foregroundColor(DSColor.Text.inverse)
            + Text(userName)
                .foregroundColor(DSColor.Text.heading)
        )
        .typography(.headingLargeSemibold)
        .padding(.horizontal, DSConstant.mediumLarge.value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timeOfDayGreeting) \(userName)".trimmingCharacters(in: .whitespaces))
    }

    /// Hardcoded Home mock values until live rank/points wiring lands.
    private var loyaltyCard: some View {
        LoyaltyCard(
            rankTitle: HomeLocalizedString.string("home.loyaltyCard.rankTitle", locale: locale),
            rankSubtitle: HomeLocalizedString.string("home.loyaltyCard.rankSubtitle", locale: locale),
            points: 3210,
            chipLabel: HomeLocalizedString.string("home.loyaltyCard.chipLabel", locale: locale),
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
        .accessibilityLabel(HomeLocalizedString.string("home.a11y.profile", locale: locale))
    }

    @ViewBuilder
    private var bellButton: some View {
        if #available(iOS 26, *) {
            Button {
                showsNotifications = true
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
            .accessibilityLabel(HomeLocalizedString.string("home.a11y.notifications", locale: locale))
        } else {
            Button {
                showsNotifications = true
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
            .accessibilityLabel(HomeLocalizedString.string("home.a11y.notifications", locale: locale))
        }
    }

    /// Flat-color placeholder banners until real Daily Offer artwork/copy is wired up —
    /// each currently just shows the shared under-construction alert on tap (see
    /// `DSBannerCarousel`).
    private var dailyOfferBanners: some View {
        DSBannerCarousel(
            items: [
                .init(id: 0, backgroundColor: DSColor.Background.pink),
                .init(id: 1, backgroundColor: DSColor.Background.brown),
                .init(id: 2, backgroundColor: DSColor.Background.green)
            ]
        )
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
    private var timeOfDayGreeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return HomeLocalizedString.string("home.greeting.morning", locale: locale)
        case 12..<17: return HomeLocalizedString.string("home.greeting.afternoon", locale: locale)
        default: return HomeLocalizedString.string("home.greeting.evening", locale: locale)
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
