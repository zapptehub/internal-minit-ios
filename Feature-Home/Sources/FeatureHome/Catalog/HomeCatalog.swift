import Foundation

struct HomeBanner: Equatable, Sendable {
    var id: String
    var fill: HomeFill
    var badge: HomeCopy
    var titleRuns: [HomeTitleRun]
    var image: HomeAsset?

    func plainTitle(locale: Locale) -> String {
        titleRuns.map { $0.text.resolved(locale: locale) }.joined()
    }
}

struct HomeProduct: Equatable, Sendable, Identifiable {
    var id: String
    var image: HomeAsset
    var label: HomeCopy
    var showDiscount: Bool
}

struct HomeChallenge: Equatable, Sendable, Identifiable {
    var id: String
    var fill: HomeFill
    var icon: HomeIconAsset
    var points: Int
    var title: HomeCopy
    var repeatCount: Int
    var progress: Int
}

struct HomeNewsCard: Equatable, Sendable, Identifiable {
    var id: String
    var image: HomeAsset
    var title: HomeCopy
}

struct HomeNotificationItem: Equatable, Sendable, Identifiable {
    var id: String
    var section: HomeNotificationSection
    var icon: HomeIconAsset
    var title: HomeCopy
    var date: HomeCopy
    var points: Int
}

/// Home document the screen renders.
///
/// Loyalty and section headings stay ids and numbers. `HomeLoyaltyCopy` formats
/// them from the in-app locale. Banner, product, challenge, news, and
/// notification copy stays as keys (firebase sample) or `{en,sk,hu}` (HTTP)
/// until the view resolves it. A language change does not fetch again.
public struct HomeCatalog: Sendable {
    var loyalty: HomeLoyaltyNumbers
    var currentTier: HomeCurrentTierNumbers
    var tiers: [HomeLoyaltyRung]
    var sectionIDs: [String]
    var dailyOfferInitialIndex: Int
    var banners: [HomeBanner]
    var products: [HomeProduct]
    var challenges: [HomeChallenge]
    var news: [HomeNewsCard]
    var notificationBanner: HomeBanner
    var notificationItems: [HomeNotificationItem]

    func sectionTitle(_ id: String, locale: Locale) -> String {
        guard sectionIDs.contains(id) else { return "" }
        return HomeLoyaltyCopy.sectionTitle(id, locale: locale)
    }

    var todayItems: [HomeNotificationItem] {
        notificationItems.filter { $0.section == .today }
    }

    var historyItems: [HomeNotificationItem] {
        notificationItems.filter { $0.section == .history }
    }
}

extension HomeCatalog: Equatable {}
