import Foundation

/// Maps `GET /v1/home` onto the catalog Home already renders.
///
/// A null `imageKey` leaves the banner artwork empty. An unknown `imageKey`
/// omits that artwork on a banner and drops a product or news card, which
/// cannot render without an image. An unknown icon or home fill drops that
/// item. The notifications banner stays: an unknown image is omitted and an
/// unknown fill uses brown. An unknown title style is left out of the run.
/// An unknown notification section is left out of today and history. Ids stay
/// the JSON ids. Section ids stay ids. Loyalty stays ids and numbers.
enum HomeCatalogMapper {
    static func catalog(_ document: HomeDocument) -> HomeCatalog {
        HomeCatalog(
            loyalty: HomeLoyaltyNumbers(
                points: document.loyalty.points,
                tierId: document.loyalty.tierId,
                progress: document.loyalty.progress
            ),
            currentTier: HomeCurrentTierNumbers(
                id: document.currentTier.id,
                pointsToNext: document.currentTier.pointsToNext,
                progress: document.currentTier.progress
            ),
            tiers: document.tiers.map {
                HomeLoyaltyRung(id: $0.id, floor: $0.floor, nextFloor: $0.nextFloor)
            },
            sectionIDs: document.sections.map(\.id),
            dailyOfferInitialIndex: document.dailyOfferInitialIndex,
            banners: document.banners.compactMap(homeBanner),
            products: document.products.compactMap(product),
            challenges: document.challenges.compactMap(challenge),
            news: document.news.compactMap(article),
            notificationBanner: notificationBanner(document.notifications.banner),
            notificationItems: document.notifications.items.compactMap(notificationItem)
        )
    }

    private static func homeBanner(_ dto: HomeBannerDTO) -> HomeBanner? {
        guard let fill = HomeFill(token: dto.backgroundToken) else { return nil }
        let image: HomeAsset?
        switch HomeImageResolution.resolve(dto.imageKey) {
        case .known(let asset):
            image = asset
        case .none, .unknown:
            image = nil
        }
        return HomeBanner(
            id: dto.id,
            fill: fill,
            badge: .text(dto.badge),
            titleRuns: runs(dto.titleRuns),
            image: image
        )
    }

    /// The cover always has one banner. An unknown image is omitted. An unknown
    /// fill uses the brown the screen already uses for that banner.
    private static func notificationBanner(_ dto: HomeBannerDTO) -> HomeBanner {
        let image: HomeAsset?
        switch HomeImageResolution.resolve(dto.imageKey) {
        case .known(let asset):
            image = asset
        case .none, .unknown:
            image = nil
        }
        return HomeBanner(
            id: dto.id,
            fill: HomeFill(token: dto.backgroundToken) ?? .brown,
            badge: .text(dto.badge),
            titleRuns: runs(dto.titleRuns),
            image: image
        )
    }

    private static func product(_ dto: HomeProductDTO) -> HomeProduct? {
        guard case .known(let asset) = HomeImageResolution.resolve(dto.imageKey) else { return nil }
        return HomeProduct(
            id: dto.id,
            image: asset,
            label: .text(dto.label),
            showDiscount: dto.showDiscount
        )
    }

    private static func challenge(_ dto: HomeChallengeDTO) -> HomeChallenge? {
        guard let fill = HomeFill(token: dto.backgroundToken),
              let icon = HomeIconAsset.resolve(dto.iconKey) else { return nil }
        return HomeChallenge(
            id: dto.id,
            fill: fill,
            icon: icon,
            points: dto.points,
            title: .text(dto.title),
            repeatCount: dto.repeatCount,
            progress: dto.progress
        )
    }

    private static func article(_ dto: HomeArticleDTO) -> HomeNewsCard? {
        guard case .known(let asset) = HomeImageResolution.resolve(dto.imageKey) else { return nil }
        return HomeNewsCard(id: dto.id, image: asset, title: .text(dto.title))
    }

    private static func notificationItem(_ dto: HomeNotificationDTO) -> HomeNotificationItem? {
        guard let section = HomeNotificationSection(token: dto.section),
              let icon = HomeIconAsset.resolve(dto.iconKey) else { return nil }
        return HomeNotificationItem(
            id: dto.id,
            section: section,
            icon: icon,
            title: .text(dto.title),
            date: .text(dto.dateLabel),
            points: dto.points
        )
    }

    private static func runs(_ dtos: [HomeTitleRunDTO]) -> [HomeTitleRun] {
        dtos.compactMap { dto in
            guard let style = HomeRunStyle(token: dto.style) else { return nil }
            return HomeTitleRun(text: .text(dto.text), style: style)
        }
    }
}
