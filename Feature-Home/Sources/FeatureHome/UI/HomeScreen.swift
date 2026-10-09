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

    private static let bellIconSize: CGFloat = 16

    var body: some View {
        DSPinnedHeaderSheet(
            header: { pinnedHeader },
            sheet: {
                VStack(spacing: 0) {
                    productsSection
                        // Matches Figma's 14pt gap between the sheet's drag handle and the
                        // products section's title/"see all" row.
                        .padding(.top, HomeSheetMetrics.productsTopSpacing)
                    challengesSection
                        .padding(.top, HomeSheetMetrics.sectionSpacing)
                    newsAndRecipesSection
                        .padding(.top, HomeSheetMetrics.sectionSpacing)
                        .padding(.bottom, HomeSheetMetrics.bottomSpacing)
                }
            }
        )
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

    /// Everything above the scrolling sheet: profile/bell bar, greeting, loyalty card, and
    /// the Daily Offer banners. Stays visually pinned as the sheet below scrolls up over it
    /// (see `DSPinnedHeaderSheet`).
    private var pinnedHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            greeting
                .padding(.top, HomeHeaderMetrics.greetingTopPadding)
            loyaltyCard
                .padding(.top, HomeHeaderMetrics.loyaltyCardTopSpacing)
                .padding(.horizontal, HomeHeaderMetrics.contentHorizontalInset)
            dailyOfferBanners
                .padding(.top, DSConstant.small.value)
                .padding(.bottom, DSConstant.mediumLarge.value)
        }
    }

    /// Leading profile + trailing bell, matching standard navigation-bar item placement.
    /// Figma draws both at 40pt, 10pt under the status bar and 20pt from the screen edges;
    /// each sits centred in a 44pt tap area (see `HomeHeaderMetrics`).
    private var headerBar: some View {
        HStack {
            profileButton
            Spacer()
            bellButton
        }
        .padding(.horizontal, HomeHeaderMetrics.headerHorizontalPadding)
        .frame(height: HomeHeaderMetrics.tapTargetSize)
        .padding(.top, HomeHeaderMetrics.headerRowTopPadding)
    }

    /// Time-of-day prefix in inverse white; profile first name in heading brown
    /// (`#331A00`). Figma "Heading/H2" 30pt with a 38pt box, centred.
    /// Pink name underline from the mock is deferred.
    private var greeting: some View {
        let timeOfDayGreeting = timeOfDayGreeting
        return (
            Text("\(timeOfDayGreeting) ")
                .foregroundColor(DSColor.Text.inverse)
            + Text(userName)
                .foregroundColor(DSColor.Text.heading)
        )
        .typography(.headingH2)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HomeHeaderMetrics.contentHorizontalInset)
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
                size: CGSize(width: HomeHeaderMetrics.iconSize, height: HomeHeaderMetrics.iconSize),
                contentMode: .fill
            )
            .clipShape(Circle())
            .frame(width: HomeHeaderMetrics.tapTargetSize, height: HomeHeaderMetrics.tapTargetSize)
            .contentShape(Circle())
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
                .frame(width: HomeHeaderMetrics.iconSize, height: HomeHeaderMetrics.iconSize)
                .glassEffect(.regular.interactive(), in: Circle())
                .frame(width: HomeHeaderMetrics.tapTargetSize, height: HomeHeaderMetrics.tapTargetSize)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
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
                .frame(width: HomeHeaderMetrics.iconSize, height: HomeHeaderMetrics.iconSize)
                .background {
                    Circle().fill(.ultraThinMaterial)
                }
                .frame(width: HomeHeaderMetrics.tapTargetSize, height: HomeHeaderMetrics.tapTargetSize)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(HomeLocalizedString.string("home.a11y.notifications", locale: locale))
        }
    }

    /// Same "Daily Offer" mock badge/title/image across all three slots (per design), only
    /// varying `backgroundColor` — each still just shows the shared under-construction
    /// alert on tap until real per-banner destinations exist (see `DSBannerCarousel`).
    /// (`DSBannerCarousel`'s "Daily Offer" badge is a fixed warm tan regardless of
    /// `backgroundColor`; only `title`'s base color varies here.)
    ///
    /// The pink banner is a light fill, so its title uses a warm tan
    /// (`dailyOfferOnLightTextColor`) instead of the white (`Text.inverse`) the other two
    /// darker banners use.
    private var dailyOfferBanners: some View {
        DSBannerCarousel(
            items: [
                .init(
                    id: 0,
                    backgroundColor: DSColor.Background.pink,
                    image: nil,
                    badgeText: dailyOfferBadge,
                    title: dailyOfferTitle(textColor: DSColor.Text.inverse)
                ),
                .init(
                    id: 1,
                    backgroundColor: DSColor.Background.brown,
                    image: .mockPasteryImage1,
                    badgeText: dailyOfferBadge,
                    title: dailyOfferTitle(textColor: DSColor.Text.inverse)
                ),
                .init(
                    id: 2,
                    backgroundColor: DSColor.Background.green,
                    image: .mockPasteryImage1,
                    badgeText: dailyOfferBadge,
                    title: dailyOfferTitle(textColor: DSColor.Text.inverse)
                )
            ],
            // Opens on the brown (2nd) banner rather than the 1st, per design.
            initialIndex: 1
        )
    }

    /// Mock product categories for the sheet — labels come from `home.products.category.*`;
    /// pastry art and which slots show a "%" badge match the Home mock. Tapping a circle
    /// or the trailing chevron still just shows the shared under-construction alert
    /// (see `DSCircleItemList`).
    private var productsSection: some View {
        DSCircleItemList(
            title: HomeLocalizedString.string("home.products.title", locale: locale),
            items: productCategories
        )
    }

    private var productCategories: [DSCircleItemList.Item] {
        [
            .init(
                id: 0,
                image: .mockPasteryImage5,
                label: HomeLocalizedString.string("home.products.category.bread", locale: locale)
            ),
            .init(
                id: 1,
                image: .mockPasteryImage2,
                label: HomeLocalizedString.string("home.products.category.bread", locale: locale),
                showDiscount: true
            ),
            .init(
                id: 2,
                image: .mockPasteryImage3,
                label: HomeLocalizedString.string("home.products.category.savoryScones", locale: locale)
            ),
            .init(
                id: 3,
                image: .mockPasteryImage4,
                label: HomeLocalizedString.string("home.products.category.pizza", locale: locale),
                showDiscount: true
            ),
            .init(
                id: 4,
                image: .mockPasteryImage1,
                label: HomeLocalizedString.string("home.products.category.mini", locale: locale)
            ),
            .init(
                id: 5,
                image: .mockPasteryImage5,
                label: HomeLocalizedString.string("home.products.category.bread", locale: locale)
            ),
            .init(
                id: 6,
                image: .mockPasteryImage2,
                label: HomeLocalizedString.string("home.products.category.bread", locale: locale),
                showDiscount: true
            ),
            .init(
                id: 7,
                image: .mockPasteryImage3,
                label: HomeLocalizedString.string("home.products.category.savoryScones", locale: locale)
            ),
            .init(
                id: 8,
                image: .mockPasteryImage4,
                label: HomeLocalizedString.string("home.products.category.pizza", locale: locale),
                showDiscount: true
            ),
            .init(
                id: 9,
                image: .mockPasteryImage1,
                label: HomeLocalizedString.string("home.products.category.mini", locale: locale)
            )
        ]
    }

    /// Mock challenges for the sheet — copy comes from `home.challenges.*`; colors, icons,
    /// and repeat/progress counts match the Home mock (see `DSChallengesCardList`).
    private var challengesSection: some View {
        DSChallengesCardList(
            title: HomeLocalizedString.string("home.challenges.title", locale: locale),
            items: challengeItems
        )
    }

    private var challengeItems: [DSChallengesCardList.Item] {
        [
            .init(
                id: 0,
                backgroundColor: DSColor.Background.orange,
                icon: .qrScanLine,
                badgeText: pointsLabel(for: 45),
                title: HomeLocalizedString.string("home.challenges.item.loyaltyCard.title", locale: locale),
                repeatCount: 4,
                progress: 1
            ),
            .init(
                id: 1,
                backgroundColor: DSColor.Background.green,
                icon: .croissant,
                badgeText: pointsLabel(for: 45),
                title: HomeLocalizedString.string("home.challenges.item.bakery.title", locale: locale)
            ),
            .init(
                id: 2,
                backgroundColor: DSColor.Background.pink,
                icon: .coffeeCup,
                badgeText: pointsLabel(for: 25),
                title: HomeLocalizedString.string("home.challenges.item.coffee.title", locale: locale)
            ),
            .init(
                id: 3,
                backgroundColor: DSColor.Background.brown,
                icon: .croissant,
                badgeText: pointsLabel(for: 45),
                title: HomeLocalizedString.string("home.challenges.item.bakeryTypes.title", locale: locale),
                repeatCount: 4,
                progress: 1
            )
        ]
    }

    /// Mock recipe cards for the sheet — copy comes from `home.newsAndRecipes.*`, titles are
    /// Slovak recipe names kept as-is across locales (see `DSMediaCardList`).
    private var newsAndRecipesSection: some View {
        DSMediaCardList(
            title: HomeLocalizedString.string("home.newsAndRecipes.title", locale: locale),
            items: [
                .init(
                    id: 0,
                    image: .mockRecipe1,
                    title: HomeLocalizedString.string("home.newsAndRecipes.item.gulas.title", locale: locale)
                ),
                .init(
                    id: 1,
                    image: .mockRecipe2,
                    title: HomeLocalizedString.string("home.newsAndRecipes.item.pinsa.title", locale: locale)
                )
            ]
        )
    }

    /// Shares `home.notifications.pointsFormat` with `NotificationsScreen`'s point rows,
    /// rather than a second "+N pts" string for the challenge badges.
    private func pointsLabel(for points: Int) -> String {
        let format = HomeLocalizedString.string("home.notifications.pointsFormat", locale: locale)
        return String(format: format, points)
    }

    private var dailyOfferBadge: String {
        HomeLocalizedString.string("home.dailyOfferBanner.badge", locale: locale)
    }

    /// Two-tone title, same `Text` + `Text` concatenation idiom as `greeting` — the "1"/"2"
    /// quantities always render in the shared brand-orange highlight color, while the rest
    /// takes `textColor` (white on dark banners, brown on the light pink one).
    private func dailyOfferTitle(textColor: Color) -> Text {
        Text(HomeLocalizedString.string("home.dailyOfferBanner.title.buy", locale: locale))
            .foregroundColor(textColor)
        + Text("1").foregroundColor(DSColor.Text.accent)
        + Text(HomeLocalizedString.string("home.dailyOfferBanner.title.get", locale: locale))
            .foregroundColor(textColor)
        + Text("2").foregroundColor(DSColor.Text.accent)
        + Text(HomeLocalizedString.string("home.dailyOfferBanner.title.croissants", locale: locale))
            .foregroundColor(textColor)
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

/// Header and greeting placement from Figma "AMP / Dashboard" (node 6093:5981).
///
/// Figma draws the avatar and bell at 40pt, 10pt below the status bar and 20pt from
/// the screen edges. The greeting box (38pt, `FontType.headingH2`) starts 16pt below
/// the icons, and the loyalty card 12pt below the greeting. Each 40pt icon sits centred
/// in a 44pt tap area, so the row and greeting padding subtract that 2pt inset to keep
/// the visible gaps on Figma's values.
enum HomeHeaderMetrics {
    static let iconSize: CGFloat = 40
    static let tapTargetSize: CGFloat = 44
    static let tapTargetInset: CGFloat = (tapTargetSize - iconSize) / 2
    static let headerTopSpacing: CGFloat = 10
    static let headerRowTopPadding: CGFloat = headerTopSpacing - tapTargetInset
    static let headerHorizontalInset: CGFloat = 20
    static let headerHorizontalPadding: CGFloat = headerHorizontalInset - tapTargetInset
    /// Figma HEAD (4088:985): the greeting ("Morning" 6070:4792) and the loyalty card
    /// container (6099:1585) are x 20, width 362 on a 402 screen, the same 20 as the
    /// icons and the Daily Offer banner. Was 16 (`DSConstant.mediumLarge`).
    static let contentHorizontalInset: CGFloat = 20
    static let greetingTopSpacing: CGFloat = DSConstant.mediumLarge.value
    static let greetingTopPadding: CGFloat = greetingTopSpacing - tapTargetInset
    static let loyaltyCardTopSpacing: CGFloat = DSConstant.medium.value
}

/// Sheet spacing from Figma BODY (node 4023:2016): Products starts 14pt under the drag
/// handle, and Products, Challenges and News & Recipes sit 24pt apart.
enum HomeSheetMetrics {
    static let productsTopSpacing: CGFloat = 14
    static let sectionSpacing: CGFloat = DSConstant.large.value
    static let bottomSpacing: CGFloat = DSConstant.mediumLarge.value
}
