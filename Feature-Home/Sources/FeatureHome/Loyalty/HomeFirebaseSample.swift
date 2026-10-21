import Foundation

/// Cardless loyalty block for the committed firebase backend.
///
/// The numbers live in `HomeFirebaseSample.json`, the same ids and numbers as
/// `contract/home.json`. Home renders them through `HomeLoyaltyCopy`. The
/// formatter does not contain the floor values.
enum HomeFirebaseSample {
    static var loyalty: HomeLoyaltyNumbers { loaded.loyalty }
    static var currentTier: HomeCurrentTierNumbers { loaded.currentTier }
    static var tiers: [HomeLoyaltyRung] { loaded.tiers }

    static func face(locale: Locale) -> HomeLoyaltyFace {
        render(loaded, locale: locale)
    }

    private struct Document: Decodable {
        struct Loyalty: Decodable {
            let points: Int
            let tierId: String
            let progress: Double
        }

        struct Tier: Decodable {
            let id: String
            let floor: Int
            let nextFloor: Int?
        }

        struct CurrentTier: Decodable {
            let id: String
            let pointsToNext: Int?
            let progress: Double
        }

        let loyalty: Loyalty
        let tiers: [Tier]
        let currentTier: CurrentTier
    }

    private struct Loaded {
        let loyalty: HomeLoyaltyNumbers
        let currentTier: HomeCurrentTierNumbers
        let tiers: [HomeLoyaltyRung]
    }

    /// Missing or undecodable sample. Unknown tier, no points, empty ring.
    /// `HomeLoyaltyCopy` supplies the neutral title and the top-tier line.
    /// Home must not crash when the bundled JSON is absent or will not decode.
    private static let neutral = Loaded(
        loyalty: HomeLoyaltyNumbers(points: 0, tierId: "", progress: 0),
        currentTier: HomeCurrentTierNumbers(id: "", pointsToNext: nil, progress: 0),
        tiers: []
    )

    private static let loaded: Loaded = load(from: .module)

    /// Reads `bundle` instead of the cached module sample. A missing or
    /// undecodable file renders the same neutral face as a bad module resource.
    static func face(locale: Locale, bundle: Bundle) -> HomeLoyaltyFace {
        render(load(from: bundle), locale: locale)
    }

    private static func render(_ loaded: Loaded, locale: Locale) -> HomeLoyaltyFace {
        HomeLoyaltyCopy.loyaltyCard(
            loyalty: loaded.loyalty,
            currentTier: loaded.currentTier,
            tiers: loaded.tiers,
            locale: locale
        )
    }

    private static func load(from bundle: Bundle) -> Loaded {
        guard let url = bundle.url(forResource: "HomeFirebaseSample", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let document = try? JSONDecoder().decode(Document.self, from: data) else {
            return neutral
        }
        return Loaded(
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
            }
        )
    }
}
