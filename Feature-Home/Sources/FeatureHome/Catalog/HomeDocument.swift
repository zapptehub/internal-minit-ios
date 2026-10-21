import Foundation

/// `GET /v1/home`. Loyalty, tiers, and `currentTier` stay ids and numbers.
/// Offers, products, challenges, news, and notifications stay localized objects.
struct HomeDocument: Decodable {
    var loyalty: HomeLoyaltyDTO
    var sections: [HomeSectionDTO]
    var dailyOfferInitialIndex: Int
    var banners: [HomeBannerDTO]
    var products: [HomeProductDTO]
    var challenges: [HomeChallengeDTO]
    var news: [HomeArticleDTO]
    var notifications: HomeNotificationsDTO
    var tiers: [HomeTierDTO]
    var currentTier: HomeCurrentTierDTO
}

struct HomeLoyaltyDTO: Decodable {
    var points: Int
    var tierId: String
    var progress: Double
}

struct HomeTierDTO: Decodable {
    var id: String
    var floor: Int
    var nextFloor: Int?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        floor = try container.decode(Int.self, forKey: .floor)
        nextFloor = try container.decodeIfPresent(Int.self, forKey: .nextFloor)
    }

    private enum CodingKeys: String, CodingKey {
        case id, floor, nextFloor
    }
}

struct HomeCurrentTierDTO: Decodable {
    var id: String
    var pointsToNext: Int?
    var progress: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        pointsToNext = try container.decodeIfPresent(Int.self, forKey: .pointsToNext)
        progress = try container.decode(Double.self, forKey: .progress)
    }

    private enum CodingKeys: String, CodingKey {
        case id, pointsToNext, progress
    }
}

struct HomeSectionDTO: Decodable {
    var id: String
}

struct HomeTitleRunDTO: Decodable {
    var text: HomeLocalizedText
    var style: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(HomeLocalizedText.self, forKey: .text)
        style = try container.decodeIfPresent(String.self, forKey: .style)
    }

    private enum CodingKeys: String, CodingKey {
        case text, style
    }
}

struct HomeBannerDTO: Decodable {
    var id: String
    var backgroundToken: String?
    var badge: HomeLocalizedText
    var titleRuns: [HomeTitleRunDTO]
    var imageKey: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        backgroundToken = try container.decodeIfPresent(String.self, forKey: .backgroundToken)
        badge = try container.decode(HomeLocalizedText.self, forKey: .badge)
        titleRuns = try container.decode([HomeTitleRunDTO].self, forKey: .titleRuns)
        imageKey = try container.decodeIfPresent(String.self, forKey: .imageKey)
    }

    private enum CodingKeys: String, CodingKey {
        case id, backgroundToken, badge, titleRuns, imageKey
    }
}

struct HomeProductDTO: Decodable {
    var id: String
    var imageKey: String
    var label: HomeLocalizedText
    var showDiscount: Bool
}

struct HomeChallengeDTO: Decodable {
    var id: String
    var backgroundToken: String?
    var iconKey: String
    var points: Int
    var title: HomeLocalizedText
    var repeatCount: Int
    var progress: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        backgroundToken = try container.decodeIfPresent(String.self, forKey: .backgroundToken)
        iconKey = try container.decode(String.self, forKey: .iconKey)
        points = try container.decode(Int.self, forKey: .points)
        title = try container.decode(HomeLocalizedText.self, forKey: .title)
        repeatCount = try container.decodeIfPresent(Int.self, forKey: .repeatCount) ?? 1
        progress = try container.decodeIfPresent(Int.self, forKey: .progress) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case id, backgroundToken, iconKey, points, title, repeatCount, progress
    }
}

struct HomeArticleDTO: Decodable {
    var id: String
    var imageKey: String
    var title: HomeLocalizedText
}

struct HomeNotificationDTO: Decodable {
    var id: String
    var section: String
    var iconKey: String
    var title: HomeLocalizedText
    var dateLabel: HomeLocalizedText
    var points: Int
}

/// Notifications block inside `GET /v1/home`. No cursor.
struct HomeNotificationsDTO: Decodable {
    var banner: HomeBannerDTO
    var items: [HomeNotificationDTO]
}

/// `notifications.json` / `GET /v1/notifications`. `nextCursor` is null on the fixture.
struct HomeNotificationsPage: Decodable {
    var banner: HomeBannerDTO
    var items: [HomeNotificationDTO]
    var nextCursor: String?
}
