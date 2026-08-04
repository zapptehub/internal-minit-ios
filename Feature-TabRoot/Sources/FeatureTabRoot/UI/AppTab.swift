import DesignSystem
import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case offers
    case map
    case card
    case game

    var id: Self { self }

    /// Key into `Core-DesignSystem`'s shared `common.tabName.*` catalog — resolved by the
    /// caller against `\.locale` via `DesignSystemLocalizedString` so the tab bar switches
    /// language in lockstep with the rest of the app.
    var titleKey: String {
        switch self {
        case .home: return "common.tabName.home"
        case .offers: return "common.tabName.offers"
        case .map: return "common.tabName.map"
        case .card: return "common.tabName.card"
        case .game: return "common.tabName.game"
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
