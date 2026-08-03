import DataProfile
import DesignSystem
import FeatureCard
import FeatureGame
import FeatureHome
import FeatureMap
import FeatureOffers
import SwiftUI

struct TabRootView: View {
    let userId: String
    let profileRepository: ProfileRepository
    let onLogOut: () -> Void
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            FeatureHome.createScreen(
                userId: userId,
                profileRepository: profileRepository,
                onLogOut: onLogOut
            )
                .tabItem { tabLabel(for: .home) }
                .tag(AppTab.home)

            FeatureOffers.createScreen()
                .tabItem { tabLabel(for: .offers) }
                .tag(AppTab.offers)

            FeatureMap.createScreen()
                .tabItem { tabLabel(for: .map) }
                .tag(AppTab.map)

            FeatureCard.createScreen()
                .tabItem { tabLabel(for: .card) }
                .tag(AppTab.card)

            FeatureGame.createScreen()
                .tabItem { tabLabel(for: .game) }
                .tag(AppTab.game)
        }
        .tint(DSColor.Background.Button.secondary)
    }

    @ViewBuilder
    private func tabLabel(for tab: AppTab) -> some View {
        (selectedTab == tab ? tab.selectedIcon : tab.unselectedIcon).image
        Text(tab.title)
    }
}
