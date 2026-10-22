import CoreNetworking
import DataProfile
import DesignSystem
import SwiftUI

/// Home tab chrome. Interaction state lives in `HomeScreenModel`, which is
/// recreated when the authenticated root remounts this screen after a re-login,
/// so loading and alert flags still reset.
struct HomeScreen: View {
    private let onLogOut: () -> Void
    private let networkClient: any NetworkClient
    private let apiBaseURL: String
    #if DEBUG
    private let failureHooks: HomeScreenFailureHooks?
    #endif
    @StateObject private var model: HomeScreenModel

    @Environment(\.locale) private var locale

    private static let bellIconSize: CGFloat = 16

    #if DEBUG
    init(
        userId: String,
        profileRepository: ProfileRepository,
        homeRepository: any HomeRepository,
        networkClient: any NetworkClient,
        apiBaseURL: String,
        onLogOut: @escaping () -> Void,
        failureHooks: HomeScreenFailureHooks? = nil
    ) {
        self.failureHooks = failureHooks
        self.onLogOut = onLogOut
        self.networkClient = networkClient
        self.apiBaseURL = apiBaseURL
        _model = StateObject(
            wrappedValue: HomeScreenModel(
                userId: userId,
                profileRepository: profileRepository,
                homeRepository: homeRepository,
                onLogOut: onLogOut
            )
        )
    }
    #else
    init(
        userId: String,
        profileRepository: ProfileRepository,
        homeRepository: any HomeRepository,
        networkClient: any NetworkClient,
        apiBaseURL: String,
        onLogOut: @escaping () -> Void
    ) {
        self.onLogOut = onLogOut
        self.networkClient = networkClient
        self.apiBaseURL = apiBaseURL
        _model = StateObject(
            wrappedValue: HomeScreenModel(
                userId: userId,
                profileRepository: profileRepository,
                homeRepository: homeRepository,
                onLogOut: onLogOut
            )
        )
    }
    #endif

    var body: some View {
        // Stays mounted when the failure flag flips, so `.task` is not restarted.
        ZStack {
            if model.showsHomeLoadFailure {
                homeLoadFailureChrome
            } else {
                catalogChrome
            }
        }
        .background(LinearGradient.minitBackground.ignoresSafeArea())
        .task { await model.loadHome() }
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
                catalog: model.catalog,
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
            get: { model.showsNotifications && !model.showsHomeLoadFailure },
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

    /// Catalog chrome. The firebase sample is this catalog for a firebase
    /// build and while an HTTP request is in flight.
    private var catalogChrome: some View {
        let sheet = DSPinnedHeaderSheet(
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
        #if DEBUG
        return sheet.onAppear {
            // Appearance, not body: a body write records the last evaluation,
            // which can run for a chrome that is not the one on screen.
            failureHooks?.showsFailure = false
            failureHooks?.bellShown = true
        }
        #else
        return sheet
        #endif
    }

    /// Profile, greeting, and the failure. The catalog and the bell are not
    /// in this tree, so a dead API cannot be read as the firebase sample.
    private var homeLoadFailureChrome: some View {
        let model = model
        let retryEnabled = !model.isLoggingOut
        let retry: () -> Void = {
            Task { await model.loadCatalog() }
        }
        let column = VStack(alignment: .leading, spacing: 0) {
            headerBar(showsBell: false)
            greeting
                .padding(.top, HomeHeaderMetrics.greetingTopPadding)
            HomeLoadFailureView(isRetryEnabled: retryEnabled) {
                retry()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if DEBUG
        return column
            .onAppear {
                failureHooks?.showsFailure = true
                failureHooks?.isRetryEnabled = retryEnabled
                failureHooks?.bellShown = false
                failureHooks?.retry = retry
                failureHooks?.logOut = {
                    model.profileTapped()
                    model.confirmLogOut()
                }
            }
            .onChange(of: retryEnabled) { _, enabled in
                failureHooks?.isRetryEnabled = enabled
            }
        #else
        return column
        #endif
    }

    /// Everything above the scrolling sheet: profile/bell bar, greeting, loyalty card, and
    /// the Daily Offer banners. Stays visually pinned as the sheet below scrolls up over it
    /// (see `DSPinnedHeaderSheet`).
    private var pinnedHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar(showsBell: true)
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
    private func headerBar(showsBell: Bool) -> some View {
        HStack {
            profileButton
            Spacer()
            if showsBell {
                bellButton
            }
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

    /// Ids and numbers from the catalog, formatted for the in-app locale.
    /// The firebase sample shows for a firebase build and while HTTP is in
    /// flight. A failed first load shows `HomeLoadFailureView` instead.
    private var loyaltyCard: some View {
        let face = HomeLoyaltyCopy.loyaltyCard(
            loyalty: model.catalog.loyalty,
            currentTier: model.catalog.currentTier,
            tiers: model.catalog.tiers,
            locale: locale
        )
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
            AvatarImage(
                avatarURL: model.avatarURL,
                apiBaseURL: apiBaseURL,
                client: networkClient
            )
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

    /// Daily Offer banners from the catalog. The firebase sample is the three
    /// slots the screen used to hard-code, opening on the second one. Title runs
    /// stay inverse and accent, resolved with the in-app locale.
    /// `DSBannerCarousel` reads `initialIndex` only in `init`, so the carousel
    /// is keyed by the catalog's banner ids and opening index. A new catalog
    /// rebuilds it and applies that index.
    private var dailyOfferBanners: some View {
        DSBannerCarousel(
            items: model.catalog.bannerItems(locale: locale),
            initialIndex: model.catalog.dailyOfferInitialIndex,
            onBannerTap: { model.showUnderConstruction(.dailyOfferBanner) }
        )
        .id(DailyOfferCarouselIdentity(
            initialIndex: model.catalog.dailyOfferInitialIndex,
            bannerIDs: model.catalog.banners.map(\.id)
        ))
    }

    /// Product categories. A missing `products` section id leaves the title empty.
    private var productsSection: some View {
        DSCircleItemList(
            title: model.catalog.sectionTitle("products", locale: locale),
            items: model.catalog.productItems(locale: locale),
            onItemTap: { model.showUnderConstruction(.product) },
            onSeeAllTap: { model.showUnderConstruction(.productsSeeAll) }
        )
    }

    private var challengesSection: some View {
        DSChallengesCardList(
            title: model.catalog.sectionTitle("challenges", locale: locale),
            items: model.catalog.challengeItems(locale: locale),
            onItemTap: { model.showUnderConstruction(.challenge) },
            onSeeAllTap: { model.showUnderConstruction(.challengesSeeAll) }
        )
    }

    private var newsAndRecipesSection: some View {
        DSMediaCardList(
            title: model.catalog.sectionTitle("news", locale: locale),
            items: model.catalog.newsItems(locale: locale),
            onItemTap: { model.showUnderConstruction(.newsAndRecipe) },
            onSeeAllTap: { model.showUnderConstruction(.newsAndRecipesSeeAll) }
        )
    }

    /// Banner ids plus the opening index. SwiftUI recreates the carousel when
    /// this value changes, which is what makes a new `initialIndex` take effect.
    private struct DailyOfferCarouselIdentity: Hashable {
        var initialIndex: Int
        var bannerIDs: [String]
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
        homeRepository: FirebaseHomeRepository(),
        networkClient: PreviewHomeNetworkClient(),
        apiBaseURL: "https://api.minit.app",
        onLogOut: {}
    )
}

private struct PreviewHomeNetworkClient: NetworkClient {
    func request<T: Decodable>(_ path: String, method: HTTPMethod) async throws -> T {
        throw NetworkError.invalidURL
    }

    func request<T: Decodable, B: Encodable>(_ path: String, method: HTTPMethod, body: B) async throws -> T {
        throw NetworkError.invalidURL
    }

    func data(_ url: URL) async throws -> Data {
        throw NetworkError.invalidURL
    }
}

private struct PreviewHomeProfileRepository: ProfileRepository {
    let name: String

    func saveProfile(userId: String, name: String, surname: String, email: String) async throws {}
    func updateName(userId: String, name: String) async throws {}
    func fetchProfile(userId: String) async throws -> ProfileData? {
        ProfileData(name: name, surname: "", email: "")
    }
}

#if DEBUG
/// Reads the failure chrome from a hosted `HomeScreen`. Debug tests only.
/// Updated from `onAppear` and `onChange`, after the chrome is on screen.
final class HomeScreenFailureHooks {
    var showsFailure = false
    var isRetryEnabled = true
    var bellShown = false
    var retry: () -> Void = {}
    var logOut: () -> Void = {}
}
#endif

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
