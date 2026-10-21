import DataProfile
import DesignSystem
import SwiftUI

/// Home tab chrome. Interaction state lives in `HomeScreenModel`, which is
/// recreated when the authenticated root remounts this screen after a re-login,
/// so loading and alert flags still reset.
struct HomeScreen: View {
    private let onLogOut: () -> Void
    @StateObject private var model: HomeScreenModel

    @Environment(\.locale) private var locale

    private static let bellIconSize: CGFloat = 16

    init(
        userId: String,
        profileRepository: ProfileRepository,
        onLogOut: @escaping () -> Void
    ) {
        self.onLogOut = onLogOut
        _model = StateObject(
            wrappedValue: HomeScreenModel(
                userId: userId,
                profileRepository: profileRepository,
                onLogOut: onLogOut
            )
        )
    }

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
        .task { await model.loadUserName() }
        .alert(HomeLocalizedString.string("home.logOut.title", locale: locale), isPresented: logOutConfirmationPresented) {
            Button(HomeLocalizedString.string("home.logOut.cancel", locale: locale), role: .cancel) {
                model.dismissLogOutConfirmation()
            }
            Button(HomeLocalizedString.string("home.logOut.title", locale: locale), role: .destructive) {
                model.onLogOut = onLogOut
                model.confirmLogOut()
            }
        } message: {
            Text(HomeLocalizedString.string("home.logOut.message", locale: locale))
        }
        .featureUnderConstructionAlert(isPresented: homeUnderConstructionAlertPresented)
        .dsPopup(isPresented: loyaltyCardDetailPresented) {
            LoyaltyCardDetailView {
                model.closeLoyaltyCardDetail()
            }
        }
        .fullScreenCover(isPresented: notificationsPresented) {
            NotificationsScreen(
                onBack: { model.closeNotifications() },
                onDailyOfferTap: { model.showUnderConstruction(.notificationsDailyOffer) },
                showsUnderConstructionAlert: notificationsUnderConstructionAlertPresented
            )
        }
        .disabled(model.isLoggingOut)
    }

    private var logOutConfirmationPresented: Binding<Bool> {
        Binding(
            get: { model.showsLogOutConfirmation },
            set: { isPresented in
                if isPresented {
                    model.profileTapped()
                } else {
                    model.hideLogOutConfirmation()
                }
            }
        )
    }

    private var loyaltyCardDetailPresented: Binding<Bool> {
        Binding(
            get: { model.showsLoyaltyCardDetail },
            set: { isPresented in
                if isPresented {
                    model.openLoyaltyCardDetail()
                } else {
                    model.closeLoyaltyCardDetail()
                }
            }
        )
    }

    private var notificationsPresented: Binding<Bool> {
        Binding(
            get: { model.showsNotifications },
            set: { isPresented in
                if isPresented {
                    model.openNotifications()
                } else {
                    model.closeNotifications()
                }
            }
        )
    }

    /// Placeholder alert on Home. While the notifications cover is up, that
    /// cover presents the same flag so the alert stays above the cover.
    private var homeUnderConstructionAlertPresented: Binding<Bool> {
        Binding(
            get: { model.showsUnderConstructionAlert && !model.showsNotifications },
            set: { isPresented in
                if !isPresented {
                    model.dismissUnderConstruction()
                }
            }
        )
    }

    private var notificationsUnderConstructionAlertPresented: Binding<Bool> {
        Binding(
            get: { model.showsUnderConstructionAlert },
            set: { isPresented in
                if !isPresented {
                    model.dismissUnderConstruction()
                }
            }
        )
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
        return DSGrowingText(
            text: "\(timeOfDayGreeting) ",
            type: .headingH2,
            color: DSColor.Text.inverse,
            accentText: model.userName,
            accentColor: DSColor.Text.heading,
            alignment: .center
        )
        .frame(maxWidth: .infinity)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, HomeHeaderMetrics.contentHorizontalInset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timeOfDayGreeting) \(model.userName)".trimmingCharacters(in: .whitespaces))
    }

    /// Firebase sample. The formatter turns tier ids and numbers into the title,
    /// the points-until line, the chip, and the ring.
    private var loyaltyCard: some View {
        let face = HomeFirebaseSample.face(locale: locale)
        return LoyaltyCard(
            rankTitle: face.rankTitle,
            rankSubtitle: face.rankSubtitle,
            points: face.points,
            chipLabel: face.chipLabel,
            rankProgress: face.rankProgress,
            showsShadow: false
        ) {
            model.openLoyaltyCardDetail()
        }
    }

    private var profileButton: some View {
        Button {
            model.profileTapped()
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
                model.openNotifications()
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
                model.openNotifications()
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
    /// `backgroundColor`. Every banner title uses white, `Text.inverse`.)
    ///
    /// The pink banner is a light fill; its title is still white (`Text.inverse`), the same
    /// as the brown and green banners.
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
            initialIndex: 1,
            onBannerTap: { model.showUnderConstruction(.dailyOfferBanner) }
        )
    }

    /// Mock product categories for the sheet — labels come from `home.products.category.*`;
    /// pastry art and which slots show a "%" badge match the Home mock. Tapping a circle
    /// or the trailing chevron still just shows the shared under-construction alert
    /// (see `DSCircleItemList`).
    private var productsSection: some View {
        DSCircleItemList(
            title: HomeLoyaltyCopy.sectionTitle("products", locale: locale),
            items: productCategories,
            onItemTap: { model.showUnderConstruction(.product) },
            onSeeAllTap: { model.showUnderConstruction(.productsSeeAll) }
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
            title: HomeLoyaltyCopy.sectionTitle("challenges", locale: locale),
            items: challengeItems,
            onItemTap: { model.showUnderConstruction(.challenge) },
            onSeeAllTap: { model.showUnderConstruction(.challengesSeeAll) }
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
            title: HomeLoyaltyCopy.sectionTitle("news", locale: locale),
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
            ],
            onItemTap: { model.showUnderConstruction(.newsAndRecipe) },
            onSeeAllTap: { model.showUnderConstruction(.newsAndRecipesSeeAll) }
        )
    }

    /// Same plural as `NotificationsScreen`'s point rows.
    private func pointsLabel(for points: Int) -> String {
        HomeLoyaltyCopy.pointsBadge(points, locale: locale)
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
