import Foundation

/// One `tiers` rung. The floors are whatever the backend (or the firebase sample) sent.
struct HomeLoyaltyRung: Equatable, Sendable {
    var id: String
    var floor: Int
    var nextFloor: Int?
}

/// `loyalty` on the home document: points, tier id, and the progress token.
struct HomeLoyaltyNumbers: Equatable, Sendable {
    var points: Int
    var tierId: String
    var progress: Double
}

/// `currentTier` on the home document. `pointsToNext` is nil on the top rung.
struct HomeCurrentTierNumbers: Equatable, Sendable {
    var id: String
    var pointsToNext: Int?
    var progress: Double
}

/// Strings and the progress token for `LoyaltyCard`.
struct HomeLoyaltyFace: Equatable, Sendable {
    var rankTitle: String
    var rankSubtitle: String
    var points: Int
    var chipLabel: String
    var rankProgress: Double
}

/// Card face, point badges, and section titles from ids and numbers.
///
/// The ring is `loyalty.progress`. This type does not recompute it. The title
/// and the next-rung lookup use `loyalty.tierId`. The subtitle uses
/// `currentTier.pointsToNext`: nil is the top-tier line, and a next rung this
/// build does not name uses the neutral points plural rather than the platinum
/// line. An unknown tier id uses the neutral name, never the raw id.
///
/// `currentTier.id` and `currentTier.progress` are not read. Android does the
/// same. If `loyalty.tierId` and `currentTier.id` disagree, the title names one
/// tier and the until-line is computed from the other.
enum HomeLoyaltyCopy {
    static func loyaltyCard(
        loyalty: HomeLoyaltyNumbers,
        currentTier: HomeCurrentTierNumbers,
        tiers: [HomeLoyaltyRung],
        locale: Locale
    ) -> HomeLoyaltyFace {
        let subtitle: String
        if let pointsToNext = currentTier.pointsToNext {
            let nextID = nextTierID(after: loyalty.tierId, tiers: tiers)
            subtitle = HomeLocalizedString.quantity(pointsUntilKey(nextID), pointsToNext, locale: locale)
        } else {
            subtitle = HomeLocalizedString.string("home.loyalty.topTier", locale: locale)
        }
        return HomeLoyaltyFace(
            rankTitle: HomeLocalizedString.string(tierKey(loyalty.tierId), locale: locale),
            rankSubtitle: subtitle,
            points: loyalty.points,
            chipLabel: HomeLocalizedString.string("home.loyaltyCard.chipLabel", locale: locale),
            rankProgress: loyalty.progress
        )
    }

    static func pointsBadge(_ points: Int, locale: Locale) -> String {
        HomeLocalizedString.quantity("home.notifications.pointsFormat", points, locale: locale)
    }

    static func sectionTitle(_ id: String, locale: Locale) -> String {
        guard let key = sectionKeys[id] else { return "" }
        return HomeLocalizedString.string(key, locale: locale)
    }

    private static let sectionKeys = [
        "products": "home.products.title",
        "challenges": "home.challenges.title",
        "news": "home.newsAndRecipes.title",
        "notifications": "home.notifications.title",
        "today": "home.notifications.section.today",
        "history": "home.notifications.section.allHistory",
    ]

    private static func nextTierID(after tierID: String, tiers: [HomeLoyaltyRung]) -> String? {
        guard let nextFloor = tiers.first(where: { $0.id == tierID })?.nextFloor else { return nil }
        return tiers.first(where: { $0.floor == nextFloor })?.id
    }

    private static func tierKey(_ id: String) -> String {
        switch id {
        case "bronze": return "home.loyalty.tier.bronze"
        case "silver": return "home.loyalty.tier.silver"
        case "gold": return "home.loyalty.tier.gold"
        case "platinum": return "home.loyalty.tier.platinum"
        default: return "home.loyalty.tier.unknown"
        }
    }

    private static func pointsUntilKey(_ nextTierID: String?) -> String {
        switch nextTierID {
        case "silver": return "home.loyalty.pointsUntil.silver"
        case "gold": return "home.loyalty.pointsUntil.gold"
        case "platinum": return "home.loyalty.pointsUntil.platinum"
        default: return "home.loyalty.pointsUntil.next"
        }
    }
}
