import DesignSystem
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case offers
    case map
    case card
    case game

    var id: Self { self }

    var title: String {
        switch self {
        case .home: return "Home"
        case .offers: return "Offers"
        case .map: return "Map"
        case .card: return "Card"
        case .game: return "Game"
        }
    }

    var selectedIcon: DSIcon {
        switch self {
        case .home: return .homeSelected
        case .offers: return .discountSelected
        case .map: return .mapSelected
        case .card: return .cardSelected
        case .game: return .gameSelected
        }
    }

    var unselectedIcon: DSIcon {
        switch self {
        case .home: return .homeUnselected
        case .offers: return .discountUnselected
        case .map: return .mapUnselected
        case .card: return .cardUnselected
        case .game: return .gameUnselected
        }
    }
}
