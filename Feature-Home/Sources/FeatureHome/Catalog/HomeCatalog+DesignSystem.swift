import DesignSystem
import SwiftUI

extension HomeFill {
    var color: Color {
        switch self {
        case .pink: return DSColor.Background.pink
        case .brown: return DSColor.Background.brown
        case .green: return DSColor.Background.green
        case .orange: return DSColor.Background.orange
        }
    }
}

extension HomeRunStyle {
    var color: Color {
        switch self {
        case .inverse: return DSColor.Text.inverse
        case .accent: return DSColor.Text.accent
        }
    }
}

extension HomeAsset {
    var dsImage: DSImage {
        switch self {
        case .pastry1: return .mockPasteryImage1
        case .pastry2: return .mockPasteryImage2
        case .pastry3: return .mockPasteryImage3
        case .pastry4: return .mockPasteryImage4
        case .pastry5: return .mockPasteryImage5
        case .gulas: return .mockRecipe1
        case .pinsa: return .mockRecipe2
        }
    }
}

extension HomeIconAsset {
    var dsIcon: DSIcon {
        switch self {
        case .qrScanLine: return .qrScanLine
        case .croissant: return .croissant
        case .coffeeCup: return .coffeeCup
        case .baguette: return .minitIcBaguette
        case .bretzel: return .minitIcBretzel
        }
    }
}

extension HomeBanner {
    /// Design-system carousels identify pages with `Int`. A JSON id that is not
    /// a decimal integer is omitted from that carousel. Notification rows keep
    /// the string id on `HomeNotificationItem`.
    func carouselItem(locale: Locale) -> DSBannerCarousel.Item? {
        guard let numericID = Int(id) else { return nil }
        return DSBannerCarousel.Item(
            id: numericID,
            backgroundColor: fill.color,
            image: image?.dsImage,
            badgeText: badge.resolved(locale: locale),
            title: titleText(locale: locale)
        )
    }

    func titleText(locale: Locale) -> Text? {
        guard let first = titleRuns.first else { return nil }
        var title = Text(first.text.resolved(locale: locale)).foregroundColor(first.style.color)
        for run in titleRuns.dropFirst() {
            title = title + Text(run.text.resolved(locale: locale)).foregroundColor(run.style.color)
        }
        return title
    }
}

extension HomeCatalog {
    func bannerItems(locale: Locale) -> [DSBannerCarousel.Item] {
        banners.compactMap { $0.carouselItem(locale: locale) }
    }

    func productItems(locale: Locale) -> [DSCircleItemList.Item] {
        products.compactMap { product in
            guard let numericID = Int(product.id) else { return nil }
            return DSCircleItemList.Item(
                id: numericID,
                image: product.image.dsImage,
                label: product.label.resolved(locale: locale),
                showDiscount: product.showDiscount
            )
        }
    }

    func challengeItems(locale: Locale) -> [DSChallengesCardList.Item] {
        challenges.compactMap { challenge in
            guard let numericID = Int(challenge.id) else { return nil }
            return DSChallengesCardList.Item(
                id: numericID,
                backgroundColor: challenge.fill.color,
                icon: challenge.icon.dsIcon,
                badgeText: HomeLoyaltyCopy.pointsBadge(challenge.points, locale: locale),
                title: challenge.title.resolved(locale: locale),
                repeatCount: challenge.repeatCount,
                progress: challenge.progress
            )
        }
    }

    func newsItems(locale: Locale) -> [DSMediaCardList.Item] {
        news.compactMap { card in
            guard let numericID = Int(card.id) else { return nil }
            return DSMediaCardList.Item(
                id: numericID,
                image: card.image.dsImage,
                title: card.title.resolved(locale: locale)
            )
        }
    }

    func notificationBannerItem(locale: Locale) -> DSBannerCarousel.Item? {
        notificationBanner.carouselItem(locale: locale)
    }
}
