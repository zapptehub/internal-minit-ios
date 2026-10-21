import Foundation

/// Sample catalog for the committed firebase backend.
///
/// Same strings, colors, images, and 3210 card the screens hard-coded. Copy
/// stays on the xcstrings keys. Loyalty numbers come from `HomeFirebaseSample`.
enum HomeFirebaseCatalog {
    static func make() -> HomeCatalog {
        HomeCatalog(
            loyalty: HomeFirebaseSample.loyalty,
            currentTier: HomeFirebaseSample.currentTier,
            tiers: HomeFirebaseSample.tiers,
            sectionIDs: ["products", "challenges", "news", "notifications", "today", "history"],
            dailyOfferInitialIndex: 1,
            banners: [
                banner(id: "0", fill: .pink, image: nil),
                banner(id: "1", fill: .brown, image: .pastry1),
                banner(id: "2", fill: .green, image: .pastry1),
            ],
            products: [
                product(id: "0", image: .pastry5, key: "home.products.category.bread", showDiscount: false),
                product(id: "1", image: .pastry2, key: "home.products.category.bread", showDiscount: true),
                product(id: "2", image: .pastry3, key: "home.products.category.savoryScones", showDiscount: false),
                product(id: "3", image: .pastry4, key: "home.products.category.pizza", showDiscount: true),
                product(id: "4", image: .pastry1, key: "home.products.category.mini", showDiscount: false),
                product(id: "5", image: .pastry5, key: "home.products.category.bread", showDiscount: false),
                product(id: "6", image: .pastry2, key: "home.products.category.bread", showDiscount: true),
                product(id: "7", image: .pastry3, key: "home.products.category.savoryScones", showDiscount: false),
                product(id: "8", image: .pastry4, key: "home.products.category.pizza", showDiscount: true),
                product(id: "9", image: .pastry1, key: "home.products.category.mini", showDiscount: false),
            ],
            challenges: [
                challenge(
                    id: "0",
                    fill: .orange,
                    icon: .qrScanLine,
                    points: 45,
                    key: "home.challenges.item.loyaltyCard.title",
                    repeatCount: 4,
                    progress: 1
                ),
                challenge(
                    id: "1",
                    fill: .green,
                    icon: .croissant,
                    points: 45,
                    key: "home.challenges.item.bakery.title",
                    repeatCount: 1,
                    progress: 0
                ),
                challenge(
                    id: "2",
                    fill: .pink,
                    icon: .coffeeCup,
                    points: 25,
                    key: "home.challenges.item.coffee.title",
                    repeatCount: 1,
                    progress: 0
                ),
                challenge(
                    id: "3",
                    fill: .brown,
                    icon: .croissant,
                    points: 45,
                    key: "home.challenges.item.bakeryTypes.title",
                    repeatCount: 4,
                    progress: 1
                ),
            ],
            news: [
                HomeNewsCard(id: "0", image: .gulas, title: .key("home.newsAndRecipes.item.gulas.title")),
                HomeNewsCard(id: "1", image: .pinsa, title: .key("home.newsAndRecipes.item.pinsa.title")),
            ],
            notificationBanner: HomeBanner(
                id: "3",
                fill: .brown,
                badge: .key("home.dailyOfferBanner.badge"),
                titleRuns: [
                    HomeTitleRun(text: .text(HomeLocalizedText(en: "15%")), style: .accent),
                    HomeTitleRun(text: .key("home.notifications.dailyOfferBanner.title.suffix"), style: .inverse),
                ],
                image: .pastry1
            ),
            notificationItems: [
                row(id: "today-first-scan-june-12", section: .today, icon: .baguette),
                row(id: "today-new-product-june-11", section: .today, icon: .bretzel),
                row(id: "history-first-scan-june-12", section: .history, icon: .baguette),
                row(id: "history-new-product-june-11-1", section: .history, icon: .bretzel),
                row(id: "history-new-product-june-11-2", section: .history, icon: .bretzel),
            ]
        )
    }

    private static func banner(id: String, fill: HomeFill, image: HomeAsset?) -> HomeBanner {
        HomeBanner(
            id: id,
            fill: fill,
            badge: .key("home.dailyOfferBanner.badge"),
            titleRuns: [
                HomeTitleRun(text: .key("home.dailyOfferBanner.title.buy"), style: .inverse),
                HomeTitleRun(text: .text(HomeLocalizedText(en: "1")), style: .accent),
                HomeTitleRun(text: .key("home.dailyOfferBanner.title.get"), style: .inverse),
                HomeTitleRun(text: .text(HomeLocalizedText(en: "2")), style: .accent),
                HomeTitleRun(text: .key("home.dailyOfferBanner.title.croissants"), style: .inverse),
            ],
            image: image
        )
    }

    private static func product(
        id: String,
        image: HomeAsset,
        key: String,
        showDiscount: Bool
    ) -> HomeProduct {
        HomeProduct(id: id, image: image, label: .key(key), showDiscount: showDiscount)
    }

    private static func challenge(
        id: String,
        fill: HomeFill,
        icon: HomeIconAsset,
        points: Int,
        key: String,
        repeatCount: Int,
        progress: Int
    ) -> HomeChallenge {
        HomeChallenge(
            id: id,
            fill: fill,
            icon: icon,
            points: points,
            title: .key(key),
            repeatCount: repeatCount,
            progress: progress
        )
    }

    private static func row(
        id: String,
        section: HomeNotificationSection,
        icon: HomeIconAsset
    ) -> HomeNotificationItem {
        let titleKey = icon == .baguette
            ? "home.notifications.row.firstScan"
            : "home.notifications.row.newProduct"
        let dateKey = icon == .baguette
            ? "home.notifications.date.june12"
            : "home.notifications.date.june11"
        return HomeNotificationItem(
            id: id,
            section: section,
            icon: icon,
            title: .key(titleKey),
            date: .key(dateKey),
            points: 45
        )
    }
}

extension HomeCatalog {
    static let firebase = HomeFirebaseCatalog.make()
}
